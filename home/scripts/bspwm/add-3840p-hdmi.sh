PRIMARY="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
[ -z "$PRIMARY" ] && PRIMARY="$(xrandr --query | awk '/ connected/{print $1; exit}')"
bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20

if [[ $(xrandr -q | grep 'HDMI-1 connected') ]]; then
xrandr --output "$PRIMARY" --primary --auto --scale 1x1 --rotate normal --output HDMI-1 --mode 3840x2160 --rotate normal --right-of "$PRIMARY"
    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19
    bspc monitor HDMI-1 -d 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "eDP-1"
    xinput map-to-output "Synaptics TM3289-002" "eDP-1"
else
    xrandr --output HDMI-1 --off
    # Remove nodes
    while bspc node 20: --kill; do
        :
    done
    # Remove workspaces
    bspc desktop -r 20
    # Remove monitor
    bspc monitor HDMI-1 -r

    bspc monitor "$PRIMARY" -d 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
    xinput map-to-output "TPPS/2 Elan TrackPoint" "all"
    xinput map-to-output "Synaptics TM3289-002" "all"
fi
