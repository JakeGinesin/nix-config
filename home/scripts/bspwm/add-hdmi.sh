#!/usr/bin/env bash
# Adds an external monitor at its native (preferred) resolution, or removes it
# if it's not connected.
#
# Usage: add-hdmi.sh [OUTPUT] [MODE]
#   OUTPUT  defaults to HDMI-1 (e.g. HDMI-2, DP-2 also work)
#   MODE    optional override, e.g. 2560x1440; otherwise detected from the monitor

OUTPUT="${1:-HDMI-1}"
MODE="$2"

PRIMARY="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
[ -z "$PRIMARY" ] && PRIMARY="$(xrandr --query | awk '/ connected/{print $1; exit}')"
bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20

if xrandr --query | grep -q "^$OUTPUT connected"; then
    if [ -z "$MODE" ]; then
        # Preferred mode is the one marked with "+" in the mode list under the output
        MODE="$(xrandr --query | awk -v out="$OUTPUT" '
            $1 == out      { found = 1; next }
            found && /^[^ \t]/ { exit }
            found && /\+/  { print $1; exit }')"
        # Fallback: first (largest) mode listed for this output
        [ -z "$MODE" ] && MODE="$(xrandr --query | awk -v out="$OUTPUT" '
            $1 == out      { found = 1; next }
            found && /^[^ \t]/ { exit }
            found          { print $1; exit }')"
    fi

    if [ -n "$MODE" ]; then
        MODE_ARGS=(--mode "$MODE")
    else
        MODE_ARGS=(--auto)
    fi

    echo "Enabling $OUTPUT at ${MODE:-auto}"
    xrandr --output "$PRIMARY" --primary --auto --scale 1x1 --rotate normal \
           --output "$OUTPUT" "${MODE_ARGS[@]}" --rotate normal --right-of "$PRIMARY"
    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
    bspc monitor "$OUTPUT" -d 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "$PRIMARY"
    xinput map-to-output "Synaptics TM3289-002" "$PRIMARY"
else
    xrandr --output "$OUTPUT" --off
    # Remove nodes
    while bspc node 20: --kill; do
        :
    done
    # Remove workspaces
    bspc desktop -r 20
    # Remove monitor
    bspc monitor "$OUTPUT" -r

    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "all"
    xinput map-to-output "Synaptics TM3289-002" "all"
fi
