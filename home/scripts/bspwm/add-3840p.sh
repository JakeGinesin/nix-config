PRIMARY="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
[ -z "$PRIMARY" ] && PRIMARY="$(xrandr --query | awk '/ connected/{print $1; exit}')"
bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20

if [[ $(xrandr -q | grep 'DP-2 connected') ]]; then
xrandr --output "$PRIMARY" --primary --auto --scale 1x1 --rotate normal --output DP-2 --mode 3840x2160 --rotate normal --right-of "$PRIMARY"
    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
    bspc monitor DP-2 -d 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "eDP-1"
    xinput map-to-output "Synaptics TM3289-002" "eDP-1"
else
    xrandr --output DP-2 --off
    # Remove nodes
    while bspc node 20: --kill; do
        :
    done
    # Remove workspaces
    bspc desktop -r 20
    # Remove monitor
    bspc monitor DP-2 -r

    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "all"
    xinput map-to-output "Synaptics TM3289-002" "all"
fi
