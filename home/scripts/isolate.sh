#!/usr/bin/env bash
# isolate: a hardened bubblewrap audit shell for NixOS
#
# ============================== THREAT MODEL ==============================
# This confines SEMI-TRUSTED code, such as unaudited dependencies, unfamiliar repos,
# build scripts you haven't read, CTF binaries, etc.
#
# It is NOT a malware sandbox. Bubblewrap shares one kernel with the host;
# a kernel LPE is a total host compromise. And the kernel is generally
# NOT trustworthy.
#
# /work defaults to a LIVE bind of a real host directory (--overlay and
# --copy change that). Malware does not need a kernel bug to win: it drops
# .envrc (direnv auto-execs), .git/hooks/*, core.fsmonitor, Makefile,
# package.json postinstall, .vscode/tasks.json, and waits for you to cd
# there on the host.
# ==========================================================================
#
# Presets:
#   isolate [DIR]              standard: net on, nix daemon on (nix develop
#                              works live), live /work, allowlisted $HOME
#   isolate --paranoid [DIR]   net off, no nix daemon, narrowed /etc,
#                              throwaway overlay /work, tight limits

set -euo pipefail

readonly PROG="$(basename "$0")"
die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }
warn() { printf '%s: %s\n' "$PROG" "$*" >&2; }

# ---------------------------------------------------------------- defaults
PARANOID=0
NET=""            # "" = follow preset
NIX_DAEMON=""
NARROW_ETC=""
WORK_MODE=""      # live | overlay | copy
FLAKE_REF=""
SEED_HISTORY=0
FRESH_NVIM=0
ALLOW_DEBUG=0
SECCOMP=1
CGROUP=1
EXTRA_KEEP=()
MEM_MAX=""; TASKS_MAX=""; CPU_QUOTA=""

usage() {
  cat <<-USAGE
	Usage: $PROG [OPTIONS] [DIR]

	  DIR                  exposed at /work (default: \$PWD)

	Presets
	  --paranoid           no net, no nix daemon, narrowed /etc, overlay /work

	/work handling
	  --live               writable bind of DIR. Changes hit your real files.
	  --overlay            writable overlay; all writes land in tmpfs and are
	                       DISCARDED on exit. DIR is never modified.
	  --copy               copy DIR to a scratch tree you can diff afterwards.

	Composable overrides
	  --net | --no-net
	  --nix-daemon | --no-nix-daemon
	                       expose /nix/var/nix/daemon-socket. The daemon runs as
	                       root and a read-only bind does NOT block connect(2)
	                       on a unix socket. Off = no live nix build inside;
	                       use --flake.
	  --flake REF          realise a dev env on the HOST, inject its env into
	                       the sandbox. Works with --no-net --no-nix-daemon.
	  --history            seed host zsh history (leaks your command lines)
	  --fresh-nvim         do not overlay ~/.local/share/nvim; start with an
	                       empty plugin tree (needs net + a compiler to rebuild)
	  --allow-debug        permit ptrace / perf_event_open / process_vm_*
	  --no-seccomp         disable the syscall filter (not recommended)
	  --no-cgroup          skip systemd-run scope (no memory/fork-bomb caps)
	  --narrow-etc | --full-etc
	  --keep-env VAR       pass one more env var through (repeatable)
	  --mem SIZE           MemoryMax   (default 12G / 4G paranoid)
	  --tasks N            TasksMax    (default 4096 / 512)
	  --cpu PCT            CPUQuota    (default 400% / 200%)
	  -h, --help
	USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --paranoid)        PARANOID=1; shift ;;
    --live)            WORK_MODE=live; shift ;;
    --overlay)         WORK_MODE=overlay; shift ;;
    --copy)            WORK_MODE=copy; shift ;;
    --net)             NET=1; shift ;;
    --no-net)          NET=0; shift ;;
    --nix-daemon)      NIX_DAEMON=1; shift ;;
    --no-nix-daemon)   NIX_DAEMON=0; shift ;;
    --narrow-etc)      NARROW_ETC=1; shift ;;
    --full-etc)        NARROW_ETC=0; shift ;;
    --flake)           FLAKE_REF="${2:?--flake needs a ref}"; shift 2 ;;
    --flake=*)         FLAKE_REF="${1#*=}"; shift ;;
    --history)         SEED_HISTORY=1; shift ;;
    --fresh-nvim)      FRESH_NVIM=1; shift ;;
    --allow-debug)     ALLOW_DEBUG=1; shift ;;
    --no-seccomp)      SECCOMP=0; shift ;;
    --no-cgroup)       CGROUP=0; shift ;;
    --keep-env)        EXTRA_KEEP+=("${2:?--keep-env needs a name}"); shift 2 ;;
    --mem)             MEM_MAX="${2:?}"; shift 2 ;;
    --tasks)           TASKS_MAX="${2:?}"; shift 2 ;;
    --cpu)             CPU_QUOTA="${2:?}"; shift 2 ;;
    -h|--help)         usage; exit 0 ;;
    --)                shift; break ;;
    -*)                die "unknown flag: $1" ;;
    *)                 break ;;
  esac
done

if (( PARANOID )); then
  MODE_NAME=paranoid
  : "${NET:=0}"; : "${NIX_DAEMON:=0}"; : "${NARROW_ETC:=1}"
  : "${WORK_MODE:=overlay}"
  : "${MEM_MAX:=4G}"; : "${TASKS_MAX:=512}"; : "${CPU_QUOTA:=200%}"
else
  MODE_NAME=standard
  : "${NET:=1}"; : "${NIX_DAEMON:=1}"; : "${NARROW_ETC:=0}"
  : "${WORK_MODE:=live}"
  : "${MEM_MAX:=12G}"; : "${TASKS_MAX:=4096}"; : "${CPU_QUOTA:=400%}"
fi

# ------------------------------------------------------------- preflight
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }
need bwrap
need python3

REAL_HOME="${HOME:?HOME unset}"
[[ -d "$REAL_HOME" ]] || die "HOME is not a directory: $REAL_HOME"

TARGET="$(realpath -e "${1:-$PWD}")" || die "no such directory: ${1:-$PWD}"
[[ -d "$TARGET" ]] || die "not a directory: $TARGET"
case "$TARGET" in
  /) die "refusing to expose / at /work" ;;
  "$REAL_HOME") die "refusing to expose all of \$HOME at /work (use a subdir)" ;;
esac

ZSH_BIN="$(command -v zsh)" || die "zsh not found"

BW_HELP="$(bwrap --help 2>&1 || true)"
has_opt() { grep -q -- "$1" <<<"$BW_HELP"; }

has_opt --size || die "bwrap too old (no --size); need >= 0.5"
DISABLE_USERNS=0
if has_opt --disable-userns; then
  DISABLE_USERNS=1
else
  warn "bwrap has no --disable-userns; relying on seccomp alone for nested userns"
fi

# Probe unprivileged overlayfs before committing to it. Needs kernel >= 5.11
# and a bwrap built with overlay support. The lower dir's filesystem matters
# (ZFS and NFS lower dirs can fail where ext4 works), so probe the real path
# rather than assuming one probe generalises.
overlay_ok() {  # overlay_ok <lowerdir>
  has_opt --tmp-overlay || return 1
  [[ -d "$1" ]] || return 1
  bwrap --unshare-user --unshare-net --ro-bind / / \
        --overlay-src "$1" --tmp-overlay /tmp true >/dev/null 2>&1
}
if [[ "$WORK_MODE" == overlay ]] && ! overlay_ok "$TARGET"; then
  warn "unprivileged overlayfs unavailable for $TARGET; falling back to --copy"
  WORK_MODE=copy
fi

# pty interposition. Without a fresh pty the sandbox inherits your terminal
# fd and can ioctl(TIOCSTI) to type into your HOST shell after you exit.
# bwrap's answer is --new-session, but setsid() leaves zsh with no
# controlling tty and kills job control. A pty in the middle fixes TIOCSTI
# (injection lands in the sandbox's own pty) AND keeps job control.
PTY_WRAP=()
if command -v script >/dev/null 2>&1; then
  PTY_WRAP=(script -q -e -c)
else
  warn "util-linux 'script' not found: no pty interposition."
  warn "  TIOCSTI keystroke injection into your host shell is possible."
  warn "  Mitigate with: sysctl dev.tty.legacy_tiocsti=0"
fi

if (( CGROUP )) && ! command -v systemd-run >/dev/null 2>&1; then
  warn "systemd-run not found; continuing without resource caps"
  CGROUP=0
fi

RUNTIME_DIR="$(mktemp -d -t isolate.XXXXXXXX)"
chmod 700 "$RUNTIME_DIR"
ZDOTDIR_HOST="$RUNTIME_DIR/zdotdir"
SANDBOX_HOME="$RUNTIME_DIR/home"
mkdir -p "$ZDOTDIR_HOST" "$SANDBOX_HOME/.config"
chmod 700 "$SANDBOX_HOME"

SCRATCH=""
trap 'rm -rf "$RUNTIME_DIR"' EXIT

# ---------------------------------------------------------------- helpers
# printf '%s\0' with ZERO arguments still runs the format once and emits a
# lone NUL, i.e. an empty argument. bwrap's parser stops at the first
# non-option, so one stray empty string silently truncates the whole args
# file. Every emission goes through this guard.
emit() { (( $# )) && printf '%s\0' "$@"; return 0; }

# bwrap --size takes BYTES. "1G" makes it die with
# "--size takes a non-zero number of bytes"
to_bytes() {
  local s="${1^^}"
  case "$s" in
    *K) printf '%s' $(( ${s%K} * 1024 )) ;;
    *M) printf '%s' $(( ${s%M} * 1024 * 1024 )) ;;
    *G) printf '%s' $(( ${s%G} * 1024 * 1024 * 1024 )) ;;
    *)  printf '%s' "$s" ;;
  esac
}
emit_tmpfs() {  # emit_tmpfs <path> <size>
  emit --size "$(to_bytes "$2")" --tmpfs "$1"
}

# ----------------------------------------------- /work: copy if requested
WORK_ARGS=()
case "$WORK_MODE" in
  live)
    WORK_ARGS=(--bind "$TARGET" /work) ;;
  overlay)
    # Writes go to an invisible tmpfs and vanish on exit; TARGET is never
    # touched. Note overlayfs-in-userns is itself nontrivial kernel surface,
    # and the upper layer is tmpfs so it counts against MemoryMax.
    WORK_ARGS=(--overlay-src "$TARGET" --tmp-overlay /work) ;;
  copy)
    SCRATCH="$(mktemp -d -t isolate-work.XXXXXXXX)"
    printf 'copying %s -> %s ...\n' "$TARGET" "$SCRATCH"
    cp -a --reflink=auto "$TARGET/." "$SCRATCH/" 2>/dev/null \
      || cp -a "$TARGET/." "$SCRATCH/"
    WORK_ARGS=(--bind "$SCRATCH" /work) ;;
  *) die "internal: bad work mode $WORK_MODE" ;;
esac

# --------------------------------------------- optional: prebuild dev env
# nix develop needs the daemon socket and the network, both of which we want
# closed. So realise the environment OUT HERE and inject only the resulting
# env vars; every store path in the closure is already readable through the
# /nix/store ro-bind.
DEVENV_FILE="$ZDOTDIR_HOST/devenv.zsh"
SHELLHOOK_FILE="$ZDOTDIR_HOST/shellhook.sh"
: > "$DEVENV_FILE"; : > "$SHELLHOOK_FILE"
if [[ -n "$FLAKE_REF" ]]; then
  need nix
  printf 'realising dev env for %s on the host ...\n' "$FLAKE_REF"
  DEV_JSON="$RUNTIME_DIR/devenv.json"
  # --profile pins a gcroot so a concurrent GC can't yank the closure.
  nix print-dev-env --json --profile "$RUNTIME_DIR/dev-profile" "$FLAKE_REF" > "$DEV_JSON" 2>/dev/null \
    || nix print-dev-env --json "$FLAKE_REF" > "$DEV_JSON" \
    || die "nix print-dev-env failed for $FLAKE_REF"

  python3 - "$DEV_JSON" "$DEVENV_FILE" "$SHELLHOOK_FILE" <<'PYEOF'
import json, shlex, sys
src, out, hook = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(src))
skip = {
    "HOME","PWD","OLDPWD","SHELL","SHLVL","TERM","IFS","_",
    "PS1","PS2","PS3","PS4","PROMPT","TMP","TEMP","TMPDIR","TEMPDIR",
    "NIX_BUILD_TOP","HOSTNAME","USER","LOGNAME","DISPLAY","XDG_RUNTIME_DIR",
    "BASH","BASHOPTS","BASH_VERSION","BASH_VERSINFO","BASHPID","BASH_ALIASES",
    "shellHook",
}
lines, dropped = [], []
for name, v in sorted(d.get("variables", {}).items()):
    if name in skip or not name.isidentifier():
        continue
    t = v.get("type")
    if t in ("exported", "var"):
        kw = "export " if t == "exported" else ""
        lines.append(f"{kw}{name}={shlex.quote(v.get('value', ''))}")
    else:
        dropped.append(f"{name} ({t})")
if d.get("bashFunctions"):
    dropped.append(f"{len(d['bashFunctions'])} bash function(s)")
with open(out, "w") as f:
    f.write("# generated by isolate from nix print-dev-env\n")
    f.write("\n".join(lines) + "\n")
with open(hook, "w") as f:
    f.write(d.get("variables", {}).get("shellHook", {}).get("value", ""))
if dropped:
    sys.stderr.write("isolate: dev env: not injected (bash-only): "
                     + ", ".join(dropped[:8]) + "\n")
PYEOF
  [[ -s "$SHELLHOOK_FILE" ]] && warn "shellHook runs under 'emulate sh'; bashisms in it may misbehave"
fi

# ------------------------------------------------------------ seccomp BPF
# bwrap --seccomp wants a compiled cBPF program on an fd, not a name list.
# Generated via libseccomp through ctypes (no python bindings needed).
#
# This is a DENYLIST. Denylists are structurally incomplete: it removes the
# well-known escape and LPE primitives, it does not enumerate safety.
SECCOMP_BPF="$RUNTIME_DIR/seccomp.bpf"
if (( SECCOMP )); then
  if ! python3 - "$ALLOW_DEBUG" > "$SECCOMP_BPF" <<'PYEOF'
import ctypes, ctypes.util, errno, glob, os, sys

allow_debug = sys.argv[1] == "1"

def load():
    cands = []
    if os.environ.get("ISOLATE_LIBSECCOMP"):
        cands.append(os.environ["ISOLATE_LIBSECCOMP"])
    f = ctypes.util.find_library("seccomp")
    if f:
        cands.append(f)
    cands += ["libseccomp.so.2", "libseccomp.so"]
    # NixOS: ctypes has no ldconfig to consult, so glob the store.
    cands += sorted(glob.glob("/nix/store/*-libseccomp-*/lib/libseccomp.so.2"))[::-1]
    for c in cands:
        try:
            return ctypes.CDLL(c, use_errno=True)
        except OSError:
            continue
    sys.exit("isolate: libseccomp.so.2 not found; set ISOLATE_LIBSECCOMP=/path, "
             "add libseccomp to your shell, or pass --no-seccomp")

L = load()

ALLOW = 0x7FFF0000
def ERRNO(e): return 0x00050000 | (e & 0xFFFF)
CMP_EQ, CMP_MASKED_EQ = 4, 7

class Arg(ctypes.Structure):
    _fields_ = [("arg", ctypes.c_uint), ("op", ctypes.c_int),
                ("a", ctypes.c_uint64), ("b", ctypes.c_uint64)]

L.seccomp_init.restype = ctypes.c_void_p
L.seccomp_init.argtypes = [ctypes.c_uint32]
L.seccomp_arch_add.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
L.seccomp_syscall_resolve_name.argtypes = [ctypes.c_char_p]
L.seccomp_syscall_resolve_name.restype = ctypes.c_int
L.seccomp_rule_add_array.argtypes = [ctypes.c_void_p, ctypes.c_uint32,
                                     ctypes.c_int, ctypes.c_uint,
                                     ctypes.POINTER(Arg)]
L.seccomp_export_bpf.argtypes = [ctypes.c_void_p, ctypes.c_int]

ctx = L.seccomp_init(ALLOW)
if not ctx:
    sys.exit("isolate: seccomp_init failed")

# Secondary personalities, so a 32-bit binary can't sidestep the filter.
if os.uname().machine == "x86_64":
    for tok in (0x40000003, 0xE000003E):   # x86, x32
        L.seccomp_arch_add(ctx, tok)

def rule(action, name, args=()):
    nr = L.seccomp_syscall_resolve_name(name.encode())
    if nr == -1:
        return                      # not known to this libseccomp; fine
    arr = (Arg * len(args))(*args) if args else None
    rc = L.seccomp_rule_add_array(ctx, action, nr, len(args), arr)
    # -EDOM: syscall absent on one of the secondary arches. Harmless.
    if rc < 0 and -rc not in (errno.EDOM, errno.EEXIST):
        sys.stderr.write(f"isolate: seccomp rule {name} failed ({-rc})\n")

EPERM = ERRNO(errno.EPERM)
# ENOSYS, not EPERM, where libc/runtimes have a documented fallback path.
ENOSYS = ERRNO(errno.ENOSYS)

# Mount / namespace manipulation: the classic escape toolkit.
for s in ("mount", "umount", "umount2", "pivot_root", "chroot", "setns",
          "move_mount", "open_tree", "mount_setattr"):
    rule(EPERM, s)
for s in ("fsopen", "fsconfig", "fsmount", "fspick"):
    rule(ENOSYS, s)

# Nested user namespaces hand back CAP_SYS_ADMIN and re-open everything above.
# bwrap --disable-userns is the primary control; this is the backstop.
CLONE_NEWUSER = 0x10000000
rule(EPERM, "clone",   (Arg(0, CMP_MASKED_EQ, CLONE_NEWUSER, CLONE_NEWUSER),))
rule(EPERM, "unshare", (Arg(0, CMP_MASKED_EQ, CLONE_NEWUSER, CLONE_NEWUSER),))
# clone3 passes flags in a struct, which cBPF cannot read -> block outright.
# ENOSYS makes glibc fall back to clone(), so threads still work.
rule(ENOSYS, "clone3")

# Large / historically exploitable surface with no use in an audit shell.
for s in ("bpf", "userfaultfd", "perf_event_open", "keyctl", "add_key",
          "request_key", "kcmp", "lookup_dcookie", "quotactl", "quotactl_fd",
          "open_by_handle_at", "name_to_handle_at", "fanotify_init",
          "fanotify_mark", "syslog", "uselib", "modify_ldt", "acct",
          "vhangup", "ustat", "_sysctl", "iopl", "ioperm", "pidfd_getfd"):
    rule(EPERM, s)
for s in ("io_uring_setup", "io_uring_enter", "io_uring_register"):
    rule(ENOSYS, s)

# Host administration. Unreachable without caps, but defence in depth.
for s in ("kexec_load", "kexec_file_load", "init_module", "finit_module",
          "delete_module", "create_module", "get_kernel_syms", "query_module",
          "nfsservctl", "swapon", "swapoff", "reboot", "sethostname",
          "setdomainname"):
    rule(EPERM, s)

if not allow_debug:
    for s in ("ptrace", "process_vm_readv", "process_vm_writev"):
        rule(EPERM, s)

# TIOCSTI / TIOCLINUX belt-and-braces alongside the pty.
rule(EPERM, "ioctl", (Arg(1, CMP_EQ, 0x5412, 0),))   # TIOCSTI
rule(EPERM, "ioctl", (Arg(1, CMP_EQ, 0x541C, 0),))   # TIOCLINUX

if L.seccomp_export_bpf(ctx, 1) < 0:
    sys.exit("isolate: seccomp_export_bpf failed")
PYEOF
  then
    die "seccomp filter generation failed (--no-seccomp to skip, but read why first)"
  fi
  [[ -s "$SECCOMP_BPF" ]] || die "seccomp filter is empty"
fi

# ----------------------------------------------------- sandbox home layout
# Allowlist, not blocklist. Binding all of $HOME and masking .ssh/.gnupg/
# .mozilla misses ~/.aws ~/.netrc ~/.npmrc ~/.pypirc ~/.docker/config.json
# ~/.kube/config ~/.config/gh ~/.password-store ~/.config/sops/age
# ~/.local/share/keyrings and every non-Firefox browser profile. 
for f in .zshrc .zshenv .zprofile .zlogin .p10k.zsh .inputrc .editorconfig .vimrc; do
  [[ -e "$REAL_HOME/$f" ]] && cp -P "$REAL_HOME/$f" "$SANDBOX_HOME/$f"
done
[[ -e "$REAL_HOME/.zsh" ]] && mkdir -p "$SANDBOX_HOME/.zsh"

# ~/.config entries are bind-mounted, NOT symlinked to their realpath.
# The old `ln -s "$(realpath ...)"` only worked when the target resolved into
# /nix/store. For a hand-managed ~/.config/nvim (a plain git checkout, which
# is the common case even on NixOS) realpath returns a path under $HOME --
# and $HOME inside the sandbox is the ro-bind of the staging tree, so the
# symlink pointed at itself and ELOOP'd. A bind mount is correct either way:
# if the source is a store symlink, bwrap follows it.
#
# The mount points must pre-exist in the staging tree. $HOME is mounted
# read-only, so bwrap cannot mkdir the destination itself.
NVIM_APP="${NVIM_APPNAME:-nvim}"
CONFIG_MOUNTS=()
for d in "$NVIM_APP" zsh git lazygit direnv bat ripgrep starship.toml; do
  src="$REAL_HOME/.config/$d"
  [[ -e "$src" ]] || continue
  if [[ -d "$src" ]]; then mkdir -p "$SANDBOX_HOME/.config/$d"
  else : > "$SANDBOX_HOME/.config/$d"; fi
  CONFIG_MOUNTS+=(--ro-bind "$src" "$REAL_HOME/.config/$d")
done

# nvim's plugin tree. Read-only would break lazy.nvim/mason (they write lock
# and state files); a bare tmpfs means re-cloning every plugin and
# recompiling every treesitter parser each session, which is impossible at
# all under --no-net. A throwaway overlay gives nvim a writable view of the
# real tree where every write is discarded and the host copy is untouched.
NVIM_MOUNTS=()
NVIM_SHARE="$REAL_HOME/.local/share/$NVIM_APP"
if (( ! FRESH_NVIM )) && [[ -d "$NVIM_SHARE" ]]; then
  if overlay_ok "$NVIM_SHARE"; then
    NVIM_MOUNTS=(--overlay-src "$NVIM_SHARE" --tmp-overlay "$NVIM_SHARE")
    # shada holds every file you have opened plus command, search and
    # register history -- yanked secrets included. swap/undo/view hold the
    # contents of files you edited. Blank them inside the overlay.
    for m in shada swap undo view sessions; do
      NVIM_MOUNTS+=(--tmpfs "$NVIM_SHARE/$m")
    done
  else
    warn "no overlay for $NVIM_SHARE; nvim starts with an empty plugin tree"
  fi
fi

touch "$RUNTIME_DIR/histfile"
if (( SEED_HISTORY )) && [[ -r "$REAL_HOME/.histfile" ]]; then
  cp "$REAL_HOME/.histfile" "$RUNTIME_DIR/histfile"
fi
touch "$SANDBOX_HOME/.histfile"
mkdir -p "$SANDBOX_HOME/.cache" "$SANDBOX_HOME/.local/state" "$SANDBOX_HOME/.local/share"

# ---------------------------------------------------------- wrapper zshrc
# ZDOTDIR sits at a fixed path inside so it doesn't leak the host mktemp
# name, and it is the ONLY part of RUNTIME_DIR bound in.
ZDOTDIR_IN=/run/isolate

cat > "$ZDOTDIR_HOST/.zshenv" <<'EOF'
[[ -r "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
EOF

cat > "$ZDOTDIR_HOST/.zshrc" <<'EOF'
if [[ ! -s "$HOME/.zshrc" ]]; then
  print -P "%K{yellow}%F{black} WARN: \$HOME/.zshrc missing or empty in the sandbox %f%k"
else
  source "$HOME/.zshrc"
fi

fc -R 2>/dev/null || true
export HISTFILE=/tmp/.zsh_history

# Injected nix dev env (from `nix print-dev-env` run on the host).
[[ -s "$ZDOTDIR/devenv.zsh" ]] && source "$ZDOTDIR/devenv.zsh"
if [[ -s "$ZDOTDIR/shellhook.sh" ]]; then
  () { emulate -L sh; source "$ZDOTDIR/shellhook.sh"; }
fi

# Prepend the banner once per precmd; p10k rebuilds PROMPT each time.
_isolate_indicator() {
  [[ -n "$ISOLATE_BANNER" && "$PROMPT" != *"$ISOLATE_BANNER"* ]] \
    && PROMPT="$ISOLATE_BANNER"$'\n'"$PROMPT"
}
typeset -ga precmd_functions
precmd_functions+=(_isolate_indicator)
EOF

# ------------------------------------------------------------- env policy
# --clearenv + allowlist. Four --unsetenv calls left GITHUB_TOKEN, AWS_*,
# OPENAI_API_KEY, DBUS_SESSION_BUS_ADDRESS, DISPLAY, WAYLAND_DISPLAY and
# XDG_RUNTIME_DIR sitting in the environment.
KEEP=(
  TERM COLORTERM TERMINFO TERMINFO_DIRS
  LANG LANGUAGE LC_ALL LC_CTYPE LC_COLLATE LC_TIME LC_NUMERIC LC_MESSAGES
  LOCALE_ARCHIVE TZ
  PATH PAGER LESS EDITOR VISUAL
  XDG_DATA_DIRS XDG_CONFIG_DIRS
  NIX_SSL_CERT_FILE SSL_CERT_FILE
  NVIM_APPNAME
)
(( ${#EXTRA_KEEP[@]} )) && KEEP+=("${EXTRA_KEEP[@]}")

ENV_ARGS=(--clearenv)
for v in "${KEEP[@]}"; do
  [[ -n "${!v-}" ]] && ENV_ARGS+=(--setenv "$v" "${!v}")
done
ENV_ARGS+=(
  --setenv HOME           "$REAL_HOME"
  --setenv USER           "${USER:-$(id -un)}"
  --setenv LOGNAME        "${LOGNAME:-$(id -un)}"
  --setenv SHELL          "$ZSH_BIN"
  --setenv ZDOTDIR        "$ZDOTDIR_IN"
  --setenv XDG_CACHE_HOME "$REAL_HOME/.cache"
  --setenv XDG_STATE_HOME "$REAL_HOME/.local/state"
  --setenv XDG_DATA_HOME  "$REAL_HOME/.local/share"
  --setenv ZSH_COMPDUMP   /tmp/.zcompdump
  --setenv ISOLATE        1
  --setenv ISOLATE_MODE   "$MODE_NAME"
)
if (( NIX_DAEMON )); then
  ENV_ARGS+=(--setenv NIX_REMOTE daemon --setenv NIX_PATH "nixpkgs=flake:nixpkgs")
fi

if (( PARANOID )); then
  BANNER='%K{magenta}%F{white}%B  PARANOID'
else
  BANNER='%K{red}%F{white}%B  ISOLATE'
fi
BANNER+="  net:$( ((NET)) && echo on || echo off )"
BANNER+="  nixd:$( ((NIX_DAEMON)) && echo on || echo off )"
BANNER+="  seccomp:$( ((SECCOMP)) && echo on || echo off )"
BANNER+="  /work:$( [[ $WORK_MODE == live ]] && echo LIVE || echo "$WORK_MODE" )"
BANNER+='  %b%f%k'
ENV_ARGS+=(--setenv ISOLATE_BANNER "$BANNER")

# ------------------------------------------------------------ filesystem
# /nix/store only. /nix would also expose /nix/var/nix/daemon-socket, and a
# read-only bind does not stop connect(2) on a unix socket, which is an
# unauthenticated channel to a root daemon.
NIX_MOUNTS=(--ro-bind /nix/store /nix/store)
if (( NIX_DAEMON )); then
  NIX_MOUNTS+=(--ro-bind-try /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket)
fi

if (( NARROW_ETC )); then
  ETC_MOUNTS=()
  for e in /etc/static /etc/passwd /etc/group /etc/nsswitch.conf /etc/hosts \
           /etc/localtime /etc/ssl /etc/pki /etc/shells /etc/zshenv /etc/zshrc \
           /etc/zinputrc /etc/set-environment /etc/profiles /etc/fonts \
           /etc/terminfo /etc/nix/nix.conf; do
    ETC_MOUNTS+=(--ro-bind-try "$e" "$e")
  done
else
  # Full /etc is a complete host software inventory: handy for you, handy
  # for anything picking an exploit.
  ETC_MOUNTS=(--ro-bind /etc /etc)
fi
(( NET )) && ETC_MOUNTS+=(--ro-bind-try /etc/resolv.conf /etc/resolv.conf)

# --unshare-net also closes the ABSTRACT unix socket namespace, which is
# scoped by netns, not IPC ns. That is what makes @/tmp/.X11-unix/X0
# (keylogging, screenshots) and anything on 127.0.0.1 reachable when the
# network is shared.
NET_ARGS=()
(( NET )) || NET_ARGS=(--unshare-net)

USERNS_ARGS=()
if (( DISABLE_USERNS )); then
  USERNS_ARGS=(--disable-userns)
  # Fail loudly rather than silently degrade when we claim to be paranoid.
  if (( PARANOID )) && has_opt --assert-userns-disabled; then
    USERNS_ARGS+=(--assert-userns-disabled)
  fi
fi

# --------------------------------------------------------- build args file
ARGS_FILE="$RUNTIME_DIR/bwrap.args"
{
  emit --die-with-parent \
       --unshare-user --unshare-pid --unshare-uts --unshare-ipc \
       --unshare-cgroup-try \
       --hostname isolate \
       --cap-drop ALL \
       --proc /proc \
       --dev /dev
  emit "${USERNS_ARGS[@]}"
  emit "${NET_ARGS[@]}"
  emit_tmpfs /tmp 1G
  emit_tmpfs /var 64M
  emit_tmpfs /run 64M
  emit "${NIX_MOUNTS[@]}"
  emit "${ETC_MOUNTS[@]}"
  emit --ro-bind-try /run/current-system/sw /run/current-system/sw
  # /run/wrappers holds NixOS setuid helpers. bwrap mounts nosuid so they
  # are inert and nothing here needs them. Omitted on purpose.

  # $HOME: only the allowlisted staging tree, read-only, then tmpfs for the
  # paths that must be writable. bwrap creates the mount point itself.
  emit --ro-bind "$SANDBOX_HOME" "$REAL_HOME"
  emit --ro-bind-try "$REAL_HOME/.zsh" "$REAL_HOME/.zsh"
  emit "${CONFIG_MOUNTS[@]}"
  emit --bind "$RUNTIME_DIR/histfile" "$REAL_HOME/.histfile"
  # Sized for a fresh plugin install: treesitter parsers and mason binaries
  # run to hundreds of MB, and 64M here fails in a very confusing way.
  emit_tmpfs "$REAL_HOME/.cache" 1G
  emit_tmpfs "$REAL_HOME/.local/state" 256M
  emit_tmpfs "$REAL_HOME/.local/share" 4G
  # After the .local/share tmpfs, so the overlay lands on top of it.
  emit "${NVIM_MOUNTS[@]}"

  emit --ro-bind "$ZDOTDIR_HOST" "$ZDOTDIR_IN"
  emit "${WORK_ARGS[@]}"
  emit --chdir /work
  emit "${ENV_ARGS[@]}"
  (( SECCOMP )) && emit --seccomp 4
} > "$ARGS_FILE"

# ------------------------------------------------------------ launch
# The args go in over an fd so in-sandbox `ps` shows only "bwrap --args 3"
# rather than the whole mount layout. Cosmetic only: /proc/self/mountinfo
# still discloses every mount and you cannot hide that from a process inside
# the namespace. Do not treat layout secrecy as a control.
#
# The COMMAND must stay on the real command line. bwrap parses an args file
# through parse_args_recurse() and drops whatever is left after the last
# recognised option, so a command placed inside the file is silently thrown
# away and bwrap exits printing its usage block.
ENTER="$RUNTIME_DIR/enter"
{
  echo '#!/usr/bin/env bash'
  printf 'exec 3< %q\n' "$ARGS_FILE"
  (( SECCOMP )) && printf 'exec 4< %q\n' "$SECCOMP_BPF"
  printf 'exec bwrap --args 3 -- %q -i\n' "$ZSH_BIN"
} > "$ENTER"
chmod 700 "$ENTER"

LAUNCH="$RUNTIME_DIR/launch"
{
  echo '#!/usr/bin/env bash'
  if (( CGROUP )); then
    printf 'exec systemd-run --user --scope --quiet --unit %q \\\n' "isolate-$$"
    printf '  -p MemoryMax=%q -p MemorySwapMax=0 \\\n' "$MEM_MAX"
    printf '  -p TasksMax=%q -p CPUQuota=%q -p IOWeight=50 \\\n' "$TASKS_MAX" "$CPU_QUOTA"
    printf '  -- %q\n' "$ENTER"
  else
    printf 'exec %q\n' "$ENTER"
  fi
} > "$LAUNCH"
chmod 700 "$LAUNCH"

set +e
if (( ${#PTY_WRAP[@]} )); then
  "${PTY_WRAP[@]}" "exec ${LAUNCH@Q}" /dev/null
else
  "$LAUNCH"
fi
rc=$?
set -e

if (( PARANOID )); then
  printf '\n\033[1;45;37m  EXITED isolate (paranoid), back on host shell  \033[0m\n'
else
  printf '\n\033[1;42;30m  EXITED isolate, back on host shell  \033[0m\n'
fi

case "$WORK_MODE" in
  overlay)
    printf '\n/work was a throwaway overlay over %s; all writes discarded.\n\n' "$TARGET" ;;
  copy)
    printf '\nscratch copy kept (%s untouched):\n  %s\n' "$TARGET" "$SCRATCH"
    printf 'inspect:  diff -rq %q %q\nthen:     rm -rf %q\n\n' \
      "$TARGET" "$SCRATCH" "$SCRATCH" ;;
  live)
    printf '\n\033[33m/work was a LIVE bind of %s\033[0m\n' "$TARGET"
    printf 'check for dropped executables before you cd there on the host:\n'
    printf '  .envrc  .git/hooks/  .git/config (fsmonitor|pager|hooksPath)\n'
    printf '  Makefile  package.json  .vscode/tasks.json\n\n' ;;
esac
exit "$rc"
