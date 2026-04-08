#!/usr/bin/env bash
bytes=$(sqlite3 /nix/var/nix/db/db.sqlite "SELECT SUM(narSize) FROM ValidPaths;")
awk -v b="$bytes" 'BEGIN {
  if (b >= 1073741824) printf "%.1fG\n", b/1073741824
  else if (b >= 1048576) printf "%.0fM\n", b/1048576
  else printf "%.0fK\n", b/1024
}'
