#!/usr/bin/env bash
# isolate, a sandboxed audit shell on NixOS via bubblewrap
#
# Modes:
#   isolate [DIR]            standard: ro home with masks, host history seeded
#   isolate --paranoid [DIR] tmpfs home, only whitelisted dotfiles bound,
#                            no history seed, tighter limits, capabilities dropped
#
# Both modes apply systemd cgroup limits (memory/tasks/CPU) to defend against
# zip bombs and fork bombs. Both keep network access for nix-shell.

set -euo pipefail

PARANOID=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --paranoid) PARANOID=1; shift ;;
    -h|--help)
      cat <<-USAGE
	Usage: $(basename "$0") [--paranoid] [DIR]
	  --paranoid  Tighter sandbox: tmpfs \$HOME, capabilities dropped, lower
	              resource limits, host shell history NOT seeded in.
	  DIR         Directory mounted writable at /work (default: \$PWD).
	USAGE
      exit 0 ;;
    --) shift; break ;;
    -*) echo "isolate: unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

TARGET="$(realpath "${1:-$PWD}")"
[[ -d "$TARGET" ]] || { echo "isolate: not a directory: $TARGET" >&2; exit 1; }

ZSH_BIN="$(command -v zsh)"
REAL_HOME="$HOME"

RUNTIME_DIR="$(mktemp -d -t isolate.XXXXXX)"
trap 'rm -rf "$RUNTIME_DIR"' EXIT

# histfile: writable shadow over ~/.histfile, seeded with host history in
# standard mode so autosuggestions / Ctrl-R work for previous commands.
touch "$RUNTIME_DIR/histfile"
if (( ! PARANOID )) && [[ -r "$REAL_HOME/.histfile" ]]; then
  cp "$REAL_HOME/.histfile" "$RUNTIME_DIR/histfile"
fi

# Wrapper zsh config
cat > "$RUNTIME_DIR/.zshenv" <<EOF
[[ -r "$REAL_HOME/.zshenv" ]] && source "$REAL_HOME/.zshenv"
EOF

cat > "$RUNTIME_DIR/.zshrc" <<'EOF'
if [[ ! -s "$HOME/.zshrc" ]]; then
  print -P "%K{yellow}%F{black} WARN: \$HOME/.zshrc missing or empty in the sandbox %f%k"
fi
source "$HOME/.zshrc"

export NIX_PATH="nixpkgs=flake:nixpkgs"

fc -R 2>/dev/null || true
export HISTFILE="/tmp/.zsh_history"

# Indicator: prepend once per precmd, never stack. p10k rebuilds PROMPT each
# precmd; we run after it and add our banner on top. If p10k isn't loaded,
# PROMPT stays static and the guard prevents stacking.
if [[ "$ISOLATE_MODE" == "paranoid" ]]; then
  _isolate_indicator() {
    [[ "$PROMPT" == *PARANOID* ]] || \
      PROMPT=$'%K{magenta}%F{white}%B  PARANOID — tmpfs home, capped resources  %b%f%k\n'"$PROMPT"
  }
else
  _isolate_indicator() {
    [[ "$PROMPT" == *ISOLATE* ]] || \
      PROMPT=$'%K{red}%F{white}%B  ISOLATE — only /work writable  %b%f%k\n'"$PROMPT"
  }
fi
typeset -ga precmd_functions
precmd_functions+=(_isolate_indicator)
EOF

# Per-mode filesystem layout and resource limits
if (( PARANOID )); then
  SANDBOX_HOME="$RUNTIME_DIR/sandbox-home"
  mkdir -p "$SANDBOX_HOME/.config"

  # Stage dotfiles. cp -P preserves symlinks-as-symlinks; targets in /nix
  # remain reachable inside the sandbox because /nix is bound.
  for f in .zshrc .zshenv .zprofile .p10k.zsh; do
    [[ -e "$REAL_HOME/$f" ]] && cp -P "$REAL_HOME/$f" "$SANDBOX_HOME/$f"
  done

  # Config dirs: symlink to resolved /nix/store paths (reachable in sandbox).
  for d in nvim zsh; do
    if [[ -e "$REAL_HOME/.config/$d" ]]; then
      ln -s "$(realpath "$REAL_HOME/.config/$d")" "$SANDBOX_HOME/.config/$d"
    fi
  done

  # ~/.zsh: just create the mount point; we ro-bind the real host directory
  # over it below. This handles the case where ~/.zsh is a regular directory
  # containing symlinks (so a top-level symlink wouldn't resolve correctly
  # against the sandbox-home overlay).
  [[ -e "$REAL_HOME/.zsh" ]] && mkdir -p "$SANDBOX_HOME/.zsh"

  # Mount points for writable bind / tmpfs masks below.
  touch "$SANDBOX_HOME/.histfile"
  mkdir -p \
    "$SANDBOX_HOME/.cache" \
    "$SANDBOX_HOME/.local/state" \
    "$SANDBOX_HOME/.local/share"

  HOME_MOUNTS=(
    --ro-bind     "$SANDBOX_HOME"           "$REAL_HOME"
    --ro-bind-try "$REAL_HOME/.zsh"         "$REAL_HOME/.zsh"
    --bind        "$RUNTIME_DIR/histfile"   "$REAL_HOME/.histfile"
    --tmpfs       "$REAL_HOME/.cache"
    --tmpfs       "$REAL_HOME/.local/state"
    --tmpfs       "$REAL_HOME/.local/share"
  )
  HARDENING=(--cap-drop ALL --new-session)
  MODE_NAME="paranoid"
  MEM_MAX="4G"; TASKS_MAX="512"; CPU_QUOTA="200%"
else
  HOME_MOUNTS=(
    --ro-bind     "$REAL_HOME"              "$REAL_HOME"
    --bind        "$RUNTIME_DIR/histfile"   "$REAL_HOME/.histfile"
    --tmpfs       "$REAL_HOME/.cache"
    --tmpfs       "$REAL_HOME/.local/state"
    --tmpfs       "$REAL_HOME/.local/share/nvim"
    --tmpfs       "$REAL_HOME/.cache/nvim"
    --tmpfs       "$REAL_HOME/.ssh"
    --tmpfs       "$REAL_HOME/.gnupg"
    --tmpfs       "$REAL_HOME/.mozilla"
  )
  HARDENING=()
  MODE_NAME="standard"
  MEM_MAX="12G"; TASKS_MAX="4096"; CPU_QUOTA="400%"
fi

set +e
systemd-run --user --scope --quiet \
    --unit "isolate-$$" \
    -p MemoryMax="$MEM_MAX" \
    -p MemorySwapMax=0 \
    -p TasksMax="$TASKS_MAX" \
    -p CPUQuota="$CPU_QUOTA" \
    -- \
  bwrap \
    --die-with-parent \
    --unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup-try \
    --hostname isolate \
    --proc /proc \
    --dev /dev \
    --tmpfs /tmp \
    --tmpfs /var \
    --tmpfs /run \
    --ro-bind /nix /nix \
    --ro-bind /etc /etc \
    --ro-bind /run/current-system /run/current-system \
    --ro-bind-try /run/wrappers /run/wrappers \
    --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
    --ro-bind "$RUNTIME_DIR" "$RUNTIME_DIR" \
    "${HOME_MOUNTS[@]}" \
    "${HARDENING[@]}" \
    --bind "$TARGET" /work \
    --chdir /work \
    --unsetenv SSH_AUTH_SOCK \
    --unsetenv SSH_AGENT_PID \
    --unsetenv GPG_AGENT_INFO \
    --unsetenv GNUPGHOME \
    --setenv ZDOTDIR      "$RUNTIME_DIR" \
    --setenv ISOLATE      "1" \
    --setenv ISOLATE_MODE "$MODE_NAME" \
    --setenv NIX_PATH     "nixpkgs=flake:nixpkgs" \
    "$ZSH_BIN" -i
rc=$?
set -e

if (( PARANOID )); then
  printf '\n\033[1;45;37m  EXITED isolate (paranoid), back on host shell  \033[0m\n\n'
else
  printf '\n\033[1;42;30m  EXITED isolate, back on host shell  \033[0m\n\n'
fi
exit "$rc"
