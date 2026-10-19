#!/usr/bin/env bash
# zotero-status         show status
# zotero-status --fix   kill any Zotero and restart the background service

if [ "$1" = --fix ]; then
  pkill -x zotero-bin; sleep 3
  systemctl --user restart zotero-background
  sleep 15
fi

s=$(systemctl --user is-active zotero-background)
p=$(ss -ltnpH 'sport = :23119' | grep -o 'pid=[0-9]*' | cut -d= -f2)
if [ -z "$p" ]; then o=nobody
elif grep -q zotero-background.service "/proc/$p/cgroup"; then o="pid $p (service)"
else o="pid $p (outside service: GUI window or leftover)"; fi
r=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:23119/connector/ping)

echo "service: $s | port 23119: $o | ping: $r"
[ "$r" = 200 ] || echo "not answering, try: $0 --fix"
