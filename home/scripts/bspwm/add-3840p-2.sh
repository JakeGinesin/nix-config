#!/usr/bin/env bash

PRIMARY="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
[ -z "$PRIMARY" ] && PRIMARY="$(xrandr --query | awk '/ connected/{print $1; exit}')"

if [[ $(xrandr -q | grep 'DP-2 connected') ]]; then
    xrandr --output "$PRIMARY" --primary --auto --scale 1x1 --rotate normal \
           --output DP-2 --mode 3840x2160 --rotate normal --right-of "$PRIMARY"

    # Assign Rows 1-9 (1_1..9_5) to primary, and Row 10 (10_1..10_5) to DP-2
    bspwm-grid init "$PRIMARY" 9
    bspc monitor DP-2 -d 10_1 10_2 10_3 10_4 10_5

    xinput map-to-output "TPPS/2 Elan TrackPoint" "$PRIMARY"
    xinput map-to-output "Synaptics TM3289-002" "$PRIMARY"
else
    xrandr --output DP-2 --off

    # Kill nodes and remove desktops in Row 10 before removing DP-2
    for c in 1 2 3 4 5; do
        while bspc node "10_${c}:" --kill; do
            :
        done
        bspc desktop -r "10_${c}" 2>/dev/null
    done

    # Remove monitor
    bspc monitor DP-2 -r 2>/dev/null

    # Restore all 10 rows (1_1..10_5) to primary
    bspwm-grid init "$PRIMARY" 10

    xinput map-to-output "TPPS/2 Elan TrackPoint" "all"
    xinput map-to-output "Synaptics TM3289-002" "all"
fi
