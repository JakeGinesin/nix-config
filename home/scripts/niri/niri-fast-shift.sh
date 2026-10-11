#!/usr/bin/env bash
# niri port of bspwm/fast-shift.sh: jump to the next/previous desktop on the
# focused monitor that actually has windows, wrapping around
dir="$1"
[[ "$dir" == left || "$dir" == right ]] || { echo "usage: niri-fast-shift left|right" >&2; exit 1; }

target=$(niri msg -j workspaces | jq -r --arg dir "$dir" '
  (map(select(.is_focused)) | first) as $cur
  | map(select(.output == $cur.output and .active_window_id != null and .id != $cur.id) | .idx)
  | sort
  | if length == 0 then empty
    elif $dir == "right" then ((map(select(. > $cur.idx)) | first) // first)
    else ((map(select(. < $cur.idx)) | last) // last)
    end')

# a bare number is a workspace index on the focused monitor
[[ -n "$target" ]] && niri msg action focus-workspace "$target"
