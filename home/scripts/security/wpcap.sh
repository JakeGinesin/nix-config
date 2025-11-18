if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

echo """
██╗    ██╗██████╗  ██████╗ █████╗ ██████╗ 
██║    ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗
██║ █╗ ██║██████╔╝██║     ███████║██████╔╝
██║███╗██║██╔═══╝ ██║     ██╔══██║██╔═══╝ 
╚███╔███╔╝██║     ╚██████╗██║  ██║██║     
 ╚══╝╚══╝ ╚═╝      ╚═════╝╚═╝  ╚═╝╚═╝     
"""

# if [ -z "$1" ]; then
    # echo "Usage: sudo $0 <interface>"
    # exit 1
# fi

INTERFACE=${1:-wlan0}
MON_INTERFACE="${INTERFACE}mon"
CAPTURE_PREFIX="caps" 
HASH_FILE="hash.hc22000"   

trap 'echo -e "\nStopping monitor mode on ${MON_INTERFACE}..."; airmon-ng stop ${MON_INTERFACE} > /dev/null 2>&1;' EXIT

echo "Starting monitor mode on ${INTERFACE}..."
airmon-ng start ${INTERFACE} > /dev/null 2>&1

echo -e "\nCapturing handshakes... Press Ctrl+C when you're done.\n"
airodump-ng --write ${CAPTURE_PREFIX} ${MON_INTERFACE}

echo -e "\nLooking for the latest capture file..."
LATEST_CAP=$(ls -t ${CAPTURE_PREFIX}*.cap 2>/dev/null | head -n 1)

if [ -z "${LATEST_CAP}" ]; then
    echo "Error: No .cap file found. Exiting."
    exit 1
fi

echo "Converting ${LATEST_CAP} to hash format..."
hcxpcapngtool -o ${HASH_FILE} ${LATEST_CAP}

echo -e "\nConversion complete. Hash saved to ${HASH_FILE}."
echo "You can now run hashcat, e.g.: hashcat -m 22000 ${HASH_FILE} /path/to/wordlist.txt"

read -p "Remove capture files (caps-*)? [y/N] " confirm

if [[ "${confirm,,}" == "y" ]]; then
    echo "Cleaning up files..."
    rm -f caps-*
    echo "Files removed."
else
    echo "Keeping capture files."
fi

echo "Script finished."
