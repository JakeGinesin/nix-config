#!/usr/bin/env bash
#
# vm-iso: a disposable, snapshot-able analysis VM. One file, no setup step
#
# depends on limactl, qemu, coreutils, util-linux (should come by-default with Jake's 
# nix environment)
#
# Tunable via env (set these in your NixOS module if you want different defaults):
#   VM_ISO_NAME VM_ISO_CPUS VM_ISO_MEMORY VM_ISO_DISK VM_ISO_ARCH
#   VM_ISO_NAG_HOURS   nag when the VM has been up this long   (default 4, 0 = never)
#   VM_ISO_IDLE_STOP   minutes with no attached shell before the VM is stopped
#                      automatically (default unset = reminders only)
#
# The guest gets, no host filesystem mounts, no SSH agent forwarding, no port
# forwards, no nothing

set -euo pipefail

: "${VM_ISO_NAME:=iso}"
: "${VM_ISO_CPUS:=4}"
: "${VM_ISO_MEMORY:=8GiB}"
: "${VM_ISO_DISK:=80GiB}"
: "${VM_ISO_ARCH:=x86_64}"   # REMnux is amd64-only
: "${VM_ISO_NAG_HOURS:=4}"
: "${VM_ISO_IDLE_STOP:=}"

I="$VM_ISO_NAME"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/vm-iso"
CFG="$STATE/$I.yaml"
STAMP="$STATE/$I.stamp"
STARTED="$STATE/$I.started"
SESS="$STATE/$I.sessions"
WPID="$STATE/$I.watchdog.pid"

die() { echo "vm-iso: $*" >&2; exit 1; }

# ----------------------------------------------------------------- VM definition
# Written out on demand; the script is the single source of truth, so a NixOS
# rebuild that changes this block is detected below rather than silently ignored :>
write_config() {
  mkdir -p "$STATE"
  cat > "$1" <<YAML
vmType: qemu          # snapshots do not work with vz
arch: $VM_ISO_ARCH
cpus: $VM_ISO_CPUS
memory: "$VM_ISO_MEMORY"
disk: "$VM_ISO_DISK"

images:
  - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    arch: x86_64

mounts: []
ssh:
  forwardAgent: false
  loadDotSSHPubKeys: false
containerd:
  system: false
  user: false
portForwards:
  - ignore: true

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eux
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends \\
        build-essential git curl wget vim tmux jq ripgrep fd-find file bsdextrautils \\
        binutils binwalk foremost sleuthkit yara upx-ucl p7zip-full unzip unrar-free \\
        radare2 gdb strace ltrace hexedit ncat socat tcpdump tshark nmap \\
        python3-dev python3-pip python3-venv pipx sqlite3 \\
        openssl gnutls-bin z3 \\
        python3-pycryptodome python3-gmpy2 python3-sympy python3-pwntools
      # heavier extras — uncomment to bake into the clean snapshot:
      # apt-get install -y sagemath ghidra
      mkdir -p /lab && chmod 1777 /lab
      curl -fsSL https://REMnux.org/remnux-cli -o /usr/local/bin/remnux
      chmod +x /usr/local/bin/remnux
YAML
}

# ----------------------------------------------------------------------- helpers
hash_file() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

exists()  { limactl list --quiet 2>/dev/null | grep -qx "$I"; }
running() { [ "$(limactl list --format '{{.Status}}' "$I" 2>/dev/null || true)" = Running ]; }

# Compare the embedded definition against the one this instance was built from.
check_drift() {
  local tmp; tmp=$(mktemp); write_config "$tmp"
  if [ -f "$STAMP" ] && [ "$(hash_file "$tmp")" != "$(cat "$STAMP")" ]; then
    echo "vm-iso: definition changed since '$I' was created — 'vm-iso rm' to rebuild" >&2
  fi
  rm -f "$tmp"
}

# --------------------------------------------------------------- uptime & nagging
start_vm() { limactl start "$I"; date +%s > "$STARTED"; }

uptime_secs() {  # echoes seconds, or nothing if unknown
  [ -f "$STARTED" ] || return 0
  echo $(( $(date +%s) - $(cat "$STARTED") ))
}

fmt_dur() {
  local s=$1
  if   [ "$s" -ge 3600 ]; then echo "$((s / 3600))h $(((s % 3600) / 60))m"
  elif [ "$s" -ge 60 ];   then echo "$((s / 60))m"
  else echo "${s}s"; fi
}

# Loud-ish notice at the start of a session if this thing has been up too long.
nag_if_old() {
  [ "$VM_ISO_NAG_HOURS" -gt 0 ] || return 0
  local up; up=$(uptime_secs); [ -n "$up" ] || return 0
  if [ "$up" -ge $((VM_ISO_NAG_HOURS * 3600)) ]; then
    echo "vm-iso: '$I' has been up $(fmt_dur "$up") — 'vm-iso reset' for a clean" >&2
    echo "        baseline, or 'vm-iso stop' to shut it down." >&2
  fi
}

# A nudge every time vm-iso is left
remind_running() {
  running || return 0
  local up msg; up=$(uptime_secs)
  msg="vm-iso: '$I' is still running"
  [ -n "$up" ] && msg="$msg (up $(fmt_dur "$up"))"
  echo "$msg ---- 'vm-iso stop' when you're done." >&2
  [ -n "$VM_ISO_IDLE_STOP" ] && \
    echo "        auto-stop after ${VM_ISO_IDLE_STOP}m idle is armed." >&2
  return 0
}

# ------------------------------------------------------- session + idle watchdog
sessions_active() {
  local f pid found=1
  mkdir -p "$SESS"
  for f in "$SESS"/*; do
    [ -e "$f" ] || continue
    pid=$(basename "$f")
    if kill -0 "$pid" 2>/dev/null; then found=0; else rm -f "$f"; fi
  done
  return $found
}

spawn_watchdog() {
  [ -n "$VM_ISO_IDLE_STOP" ] || return 0
  if [ -f "$WPID" ] && kill -0 "$(cat "$WPID" 2>/dev/null)" 2>/dev/null; then return 0; fi
  if command -v setsid >/dev/null; then
    setsid "$0" _watchdog >>"$STATE/$I.watchdog.log" 2>&1 &
  else
    nohup "$0" _watchdog >>"$STATE/$I.watchdog.log" 2>&1 &
  fi
  disown 2>/dev/null || true
}

up() {
  command -v limactl >/dev/null || die "limactl not on PATH"
  if ! exists; then
    write_config "$CFG"
    echo "vm-iso: building '$I'. The first run downloads the base image, takes a few minutes"
    limactl start --name="$I" "$CFG" --tty=false
    hash_file "$CFG" > "$STAMP"
    date +%s > "$STARTED"
  else
    check_drift
    running || start_vm
  fi
  spawn_watchdog
}

guest() { limactl shell --workdir /lab "$I" -- "$@"; }

# Snapshots need the instance stopped, so wrap the stop/act/start dance once.
with_stopped() {
  local was_running=no
  if running; then was_running=yes; limactl stop "$I"; fi
  "$@"
  [ "$was_running" = yes ] && start_vm || true
}

usage() {
  cat <<'EOF'
vm-iso                    start if needed, drop into a shell at /lab
vm-iso status             uptime, snapshots, attached sessions
vm-iso in  <file>         copy a file from the host into /lab
vm-iso out <file> [dest]  copy a file from /lab back to the host
vm-iso net off|on         cut or restore guest networking
vm-iso snap  [tag]        save VM state       (default tag: clean)
vm-iso reset [tag]        roll back, discarding everything since
vm-iso snaps              list snapshots
vm-iso remnux             add the full REMnux toolkit (~1h, needs guest net)
vm-iso stop               shut the VM down
vm-iso rm                 delete the VM and all its snapshots

typical loop:
  vm-iso in ./sample.bin && vm-iso net off && vm-iso
  vm-iso reset

leaving it up: you get a nudge on every shell exit, and a louder one once the
VM passes VM_ISO_NAG_HOURS (default 4). Set VM_ISO_IDLE_STOP=<minutes> to have
it shut itself down once no shell has been attached for that long.
EOF
}

case "${1:-shell}" in
  shell)
    up
    nag_if_old
    mkdir -p "$SESS"; touch "$SESS/$$"
    trap 'rm -f "$SESS/$$"; remind_running' EXIT
    limactl shell --workdir /lab "$I" || true
    ;;
  status)
    if ! exists; then echo "not created"; exit 0; fi
    if running; then
      up_s=$(uptime_secs)
      echo "running${up_s:+ (up $(fmt_dur "$up_s"))}"
      sessions_active && echo "shells attached: $(ls -1 "$SESS" 2>/dev/null | wc -l)" \
                      || echo "shells attached: none"
      [ -n "$VM_ISO_IDLE_STOP" ] && echo "auto-stop: ${VM_ISO_IDLE_STOP}m idle" \
                                 || echo "auto-stop: off (reminders only)"
    else
      echo "stopped"
    fi
    limactl snapshot list "$I" 2>/dev/null || true
    ;;
  in)
    [ $# -ge 2 ] || die "usage: vm-iso in <file>"
    [ -e "$2" ]  || die "no such file: $2"
    up
    limactl copy "$2" "$I:/lab/$(basename "$2")"
    echo "-> /lab/$(basename "$2")"
    ;;
  out)
    [ $# -ge 2 ] || die "usage: vm-iso out <file> [dest]"
    limactl copy "$I:/lab/$2" "${3:-.}"
    ;;
  net)
    case "${2:-}" in
      off|down) s=down ;;
      on|up)    s=up ;;
      *) die "usage: vm-iso net off|on" ;;
    esac
    up
    for n in $(guest bash -c 'ls /sys/class/net | grep -v "^lo$"'); do
      guest sudo ip link set "$n" "$s"
    done
    echo "guest interfaces: $s"
    ;;
  snap)
    exists || die "no VM yet — run vm-iso first"
    tag="${2:-clean}"
    with_stopped bash -c "limactl snapshot delete '$I' --tag '$tag' 2>/dev/null || true
                          limactl snapshot create '$I' --tag '$tag'"
    echo "saved '$tag'"
    ;;
  reset)
    exists || die "no VM yet — run vm-iso first"
    tag="${2:-clean}"
    with_stopped limactl snapshot apply "$I" --tag "$tag"
    echo "rolled back to '$tag'"
    ;;
  snaps) limactl snapshot list "$I" ;;
  remnux)
    up
    guest sudo remnux install --mode=addon
    echo "done — reboot the guest, then: vm-iso snap clean"
    ;;
  stop)
    limactl stop "$I"
    rm -f "$STARTED"
    ;;
  rm)
    limactl delete --force "$I"
    rm -rf "$CFG" "$STAMP" "$STARTED" "$SESS" "$WPID"
    ;;
  _watchdog)   # internal: stop the VM once no shell has been attached for a while
    [ -n "$VM_ISO_IDLE_STOP" ] || exit 0
    echo "$$" > "$WPID"
    trap 'rm -f "$WPID"' EXIT
    idle=0
    while :; do
      sleep 60
      running || break
      if sessions_active; then idle=0; else idle=$((idle + 1)); fi
      if [ "$idle" -ge "$VM_ISO_IDLE_STOP" ]; then
        echo "$(date -Is) idle ${VM_ISO_IDLE_STOP}m — stopping $I"
        limactl stop "$I" || true
        rm -f "$STARTED"
        break
      fi
    done
    ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac

