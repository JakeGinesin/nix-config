import subprocess, os, sys
from datetime import datetime

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

# entry point
def main():
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", sys.executable, *sys.argv])

    print(f"── brief · {datetime.now():%Y-%m-%d %H:%M} ──")
    disk_health()

main()
