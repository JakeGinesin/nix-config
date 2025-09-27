if [ -z "$1" ]; then
  echo "Usage: $0 domain.com"
  exit 1
fi

DOMAIN="$1"
OUTPUT_FILE="ips.txt"
SUBS_FILE="subs.txt"

echo "[*] Enumerating subdomains for $DOMAIN..."
subfinder -silent -d "$DOMAIN" -o "$SUBS_FILE"

if [ ! -s "$SUBS_FILE" ]; then
  echo "[!] No subdomains found or subfinder failed."
  exit 1
fi

echo "[*] Resolving IPs..."
> "$OUTPUT_FILE"

while read -r sub; do
  ips=$(dig +short "$sub" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
  if [ -n "$ips" ]; then
    for ip in $ips; do
      echo "[+] $sub resolved to $ip"
      echo "$ip" >> "$OUTPUT_FILE"
    done
  else
    echo "[-] $sub did not resolve"
  fi
done < "$SUBS_FILE"

echo "[*] IPs saved to $OUTPUT_FILE"
