#!/usr/bin/env bash
OUTPUT="${1:-HDMI-1}"
MODE="$2"

PRIMARY="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
[ -z "$PRIMARY" ] && PRIMARY="$(xrandr --query | awk '/ connected/{print $1; exit}')"

if xrandr --query | grep -q "^$OUTPUT connected"; then
    if [ -z "$MODE" ]; then
        MODE="$(xrandr --query | awk -v out="$OUTPUT" '
            $1 == out      { found = 1; next }
            found && /^[^ \t]/ { exit }
            found && /\+/  { print $1; exit }')"
        [ -z "$MODE" ] && MODE="$(xrandr --query | awk -v out="$OUTPUT" '
            $1 == out      { found = 1; next }
            found && /^[^ \t]/ { exit }
            found          { print $1; exit }')"
    fi

    MODE_ARGS=(${MODE:+--mode "$MODE"})
    [ ${#MODE_ARGS[@]} -eq 0 ] && MODE_ARGS=(--auto)

    xrandr --output "$PRIMARY" --primary --auto --scale 1x1 --rotate normal \
           --output "$OUTPUT" "${MODE_ARGS[@]}" --rotate normal --right-of "$PRIMARY"

    # Rows 1-9 on primary, Row 10 (10_1..10_5) on external monitor
    bspwm-grid init "$PRIMARY" 9
    bspc monitor "$OUTPUT" -d 10_1 10_2 10_3 10_4 10_5

    xinput map-to-output "TPPS/2 Elan TrackPoint" "$PRIMARY"
    xinput map-to-output "Synaptics TM3289-002" "$PRIMARY"
else
    xrandr --output "$OUTPUT" --off
    for c in 1 2 3 4 5; do
        while bspc node "10_${c}:" --kill; do :; done
        bspc desktop -r "10_${c}" 2>/dev/null
    done
    bspc monitor "$OUTPUT" -r 2>/dev/null

    bspwm-grid init "$PRIMARY" 10
    xinput map-to-output "TPPS/2 Elan TrackPoint" "all"
    xinput map-to-output "Synaptics TM3289-002" "all"
fi
