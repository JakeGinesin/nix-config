#!/usr/bin/env bash
# niri has close-window but no kill; this is `bspc node -k`
pid=$(niri msg -j focused-window | jq -r '.pid // empty')
[[ -n "$pid" ]] || exit 0

# every X11 window reports xwayland-satellite's pid, and that one process hosts
# all of them. SIGKILLing it would take out every X app, so only ask nicely.
if [[ "$(readlink -f "/proc/$pid/exe")" == *xwayland-satellite* ]]; then
  niri msg action close-window
  exit 0
fi

kill -9 "$pid"
