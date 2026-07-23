import subprocess, os, sys, json, re
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

USER = "synchronous"  # backups + SSH keys live under this user

REPOS = {
    "journal": {
        "path": "/home/synchronous/backups/journal",
        "auth": "--password-file /home/synchronous/.agenix/agenix/restic-password",
    },
    "keepass": {
        "path": "/home/synchronous/backups/keepass",
        "auth": "--insecure-no-password",
    },
}

def term_exe(script):
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
    )
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)

def disk_health():
    print(f"── drive health")

    # get stuff from smart log
    # TODO: compress smart-log outputs a bit; output ranges
    script = """
    ROOTDISK=/dev/$(lsblk -no PKNAME $(findmnt -no SOURCE /) | head -1)
    echo "results for $ROOTDISK":
    sudo nvme smart-log $ROOTDISK | awk -F: '/^(critical_warning|media_errors|percentage_used|available_spare[[:space:]])/{gsub(/ /,"",$2); print $1":"$2}'
    sudo dmesg -T --level=err,warn | rg -i 'nvme|i/o' | rg -v 'unchecked data buffer' | tail -3
    """
    term_exe(script)

def _ago(dt):
    s = int((datetime.now(timezone.utc) - dt).total_seconds())
    d, r = divmod(s, 86400)
    h, r = divmod(r, 3600)
    m, _ = divmod(r, 60)
    if d: return f"{d}d {h}h ago"
    if h: return f"{h}h {m}m ago"
    return f"{m}m ago"

def _tailscale_up():
    try:
        r = subprocess.run(["tailscale", "status", "--json"],
                           capture_output=True, text=True)
        return json.loads(r.stdout).get("BackendState") == "Running"
    except (json.JSONDecodeError, FileNotFoundError):
        return False

def _last_snapshot(cfg):
    # source the zsh aliases (same as the backup scripts), list snapshots as json,
    # run as USER so restic uses that user's SSH keys / repo access
    script = (
        f"source /home/{USER}/.agenix/agenix/zsh_remote\n"
        f"restic -r sftp:${{aliases[kubeserver]#ssh }}:{cfg['path']} "
        f"snapshots --json {cfg['auth']}"
    )
    r = subprocess.run(
        ["sudo", "-u", USER, "-H", "zsh", "-c", script],
        capture_output=True, text=True,
    )
    try:
        snaps = json.loads(r.stdout)
        times = [
            datetime.fromisoformat(re.sub(r"\.\d+", "", s["time"]).replace("Z", "+00:00"))
            for s in snaps
        ]
        return max(times), r.stderr
    except (json.JSONDecodeError, ValueError, KeyError):
        return None, r.stderr  # no snapshots or restic failed (e.g. can't connect)

def backup_start():
    # kick off the (slow, network-bound) queries in the background
    if not _tailscale_up():
        return None
    ex = ThreadPoolExecutor(max_workers=len(REPOS))
    futures = {ex.submit(_last_snapshot, cfg): name for name, cfg in REPOS.items()}
    return ex, futures

def backup_report(handle):
    print(f"── backups")
    if handle is None:
        print("  ✗ tailscale down — skipping backup check", file=sys.stderr)
        return
    ex, futures = handle
    for fut in as_completed(futures):              # print in whatever order finishes
        name = futures[fut]
        dt, err = fut.result()
        if dt:
            print(f"  {name:8} {dt:%Y-%m-%d %H:%M}  ({_ago(dt)})")
        else:
            msg = (err.strip().splitlines() or ["no snapshots / can't connect"])[-1]
            print(f"  {name:8} ✗ {msg}", file=sys.stderr)
    ex.shutdown()

def system_health():
    script = r"""
    # failed systemd units (broken services + backup timers)
    systemctl --failed --no-legend --plain | awk '{print "  ✗ "$1}'

    # real filesystems >=85% full
    df -hP -x tmpfs -x devtmpfs -x efivarfs \
        | awk 'NR>1 && int($5)>=85 {print "  ✗ "$6"  "$5"  ("$4" free)"}'

    # nixos: booted kernel/initrd/modules vs built system -> reboot pending?
    if [ -e /run/booted-system ] && [ -e /run/current-system ]; then
        b=$(readlink /run/booted-system/{initrd,kernel,kernel-modules})
        c=$(readlink /run/current-system/{initrd,kernel,kernel-modules})
        if [ -z "$b" ] || [ -z "$c" ]; then
            echo "  ✗ reboot check failed (couldn't read system links)"
        elif [ "$b" != "$c" ]; then
            echo "  ✗ reboot needed (booted != built)"
        fi
    fi
    """
    r = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
    out = (r.stdout + r.stderr).rstrip()
    if out:                       # only show the section when something's wrong
        print(f"── system")
        print(out)

# entry point
def main():
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", sys.executable, *sys.argv])
    print(f"── brief · {datetime.now():%Y-%m-%d %H:%M} ──")
    backups = backup_start()   # fire off network queries now
    system_health()            # fast local checks
    disk_health()              # runs while backups are in flight
    backup_report(backups)     # collect + print at the end

main()
