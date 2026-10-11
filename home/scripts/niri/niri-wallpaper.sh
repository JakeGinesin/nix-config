#!/usr/bin/env bash
# wayland stand-in for `nitrogen --restore`: show whatever nitrogen last set,
# else the first thing in ~/.wallpapers
cfg="$HOME/.config/nitrogen/bg-saved.cfg"
img=""
[[ -f "$cfg" ]] && img=$(awk -F= '$1 == "file" { print $2; exit }' "$cfg")
[[ -f "$img" ]] || img=$(find "$HOME/.wallpapers" -maxdepth 1 -type f 2>/dev/null | sort | head -n1)
[[ -n "$img" ]] || exit 0
exec swaybg -m fill -i "$img"
