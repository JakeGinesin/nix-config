#!/usr/bin/env bash
# Kills Alacritty processes that don't own any window managed by bspwm.
#
# Usage: kill-unowned-alacritty.sh [-n]
#   -n  dry run: list the processes that would be killed, but don't kill them

DRY_RUN=0
[[ "$1" == "-n" ]] && DRY_RUN=1

# PIDs that own at least one managed Alacritty window (any desktop, incl. hidden)
managed=$(for n in $(bspc query -N -n .window); do
    xprop -id "$n" WM_CLASS 2>/dev/null | grep -qi alacritty &&
        xprop -id "$n" _NET_WM_PID 2>/dev/null | awk '{print $3}'
done)

count=0
for pid in $(pgrep -x alacritty); do
    grep -qx "$pid" <<< "$managed" && continue
    count=$((count + 1))
    if (( DRY_RUN )); then
        ps -o pid=,etime=,args= -p "$pid"
    else
        kill "$pid" && echo "killed $pid"
    fi
done

(( count == 0 )) && echo "no unowned alacritty processes"
