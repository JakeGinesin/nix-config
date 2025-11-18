#!/usr/bin/env bash
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi
OP=${1:-}; DOMAIN=${2:-}
[[ $OP =~ ^(on|off)$ && -n $DOMAIN ]] || {
    echo "usage: dnsblock on|off <domain>"; exit 1; }

FILE="/var/lib/dnsmasq/conf.d/block-$DOMAIN.conf"

if [[ $OP == on ]]; then
    tee "$FILE" >/dev/null <<EOF
address=/${DOMAIN}/0.0.0.0
address=/${DOMAIN}/::
address=/www.${DOMAIN}/0.0.0.0
address=/www.${DOMAIN}/::

EOF
else
    rm -f "$FILE"
fi
