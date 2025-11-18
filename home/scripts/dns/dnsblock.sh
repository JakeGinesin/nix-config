#!/usr/bin/env bash
set -euo pipefail
OP=${1:-}; DOMAIN=${2:-}
[[ $OP =~ ^(on|off)$ && -n $DOMAIN ]] || {
    echo "usage: dnsblock on|off <domain>"; exit 1; }

FILE="/var/lib/dnsmasq/conf.d/block-$DOMAIN.conf"

if [[ $OP == on ]]; then
    sudo tee "$FILE" >/dev/null <<EOF
address=/${DOMAIN}/0.0.0.0
address=/${DOMAIN}/::
address=/www.${DOMAIN}/0.0.0.0
address=/www.${DOMAIN}/::
EOF
else
    sudo rm -f "$FILE"
fi

sudo systemctl restart dnsmasq
# sudo systemctl reload dnsmasq
