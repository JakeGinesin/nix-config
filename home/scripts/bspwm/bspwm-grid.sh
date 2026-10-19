#!/usr/bin/env bash

ROWS=10
COLS=5

get_coords() {
    local cur
    cur=$(bspc query -D -d focused --names)
    if [[ "$cur" =~ ^([0-9]+)_([0-9]+)$ ]]; then
        ROW="${BASH_REMATCH[1]}"
        COL="${BASH_REMATCH[2]}"
    else
        ROW=1
        COL=1
    fi
}

apply_target() {
    local target="$1" mode="${2:-focus}"
    case "$mode" in
        focus) bspc desktop -f "$target" ;;
        send)  bspc node -d "$target" ;;
        follow) bspc node -d "$target" --follow ;;
        swap)
            local cur
            cur=$(bspc query -D -d focused --names)
            [[ "$target" == "$cur" ]] && exit 0
            bspc desktop "$target" -n tmp_swap
            bspc desktop "$cur" -s tmp_swap
            bspc desktop "$cur" -n "$target"
            bspc desktop tmp_swap -n "$cur"
            ;;
    esac
}

case "$1" in
    init)
        # Usage: bspwm-grid init [MONITOR] [MAX_ROW]
        mon="${2:-$(bspc query -M -m focused --names)}"
        max_r="${3:-$ROWS}"
        desks=()
        for ((r=1; r<=max_r; r++)); do
            for ((c=1; c<=COLS; c++)); do
                desks+=("${r}_${c}")
            done
        done
        bspc monitor "$mon" -d "${desks[@]}"
        ;;

    col)
        # Usage: bspwm-grid col <1-5> [focus|send|swap]
        get_coords
        apply_target "${ROW}_${2}" "${3:-focus}"
        ;;

    row)
        # Usage: bspwm-grid row <1-10> [focus|send|swap]
        get_coords
        apply_target "${2}_${COL}" "${3:-focus}"
        ;;

    step-row)
        # Usage: bspwm-grid step-row <up|down> [focus|send]
        get_coords
        if [[ "$2" == "up" ]]; then
            next_r=$(( (ROW - 2 + ROWS) % ROWS + 1 ))
        else
            next_r=$(( ROW % ROWS + 1 ))
        fi
        apply_target "${next_r}_${COL}" "${3:-focus}"
        ;;

    step-col)
        # Usage: bspwm-grid step-col <left|right> [focus|send]
        get_coords
        if [[ "$2" == "left" ]]; then
            next_c=$(( (COL - 2 + COLS) % COLS + 1 ))
        else
            next_c=$(( COL % COLS + 1 ))
        fi
        apply_target "${ROW}_${next_c}" "${3:-focus}"
        ;;

    fast-shift)
        # Jump to prev/next occupied desktop in current row (or wrap across grid)
        # Usage: bspwm-grid fast-shift <left|right>
        get_coords
        cur="${ROW}_${COL}"
        mapfile -t occupied < <(bspc query -D -d .occupied --names)
        [[ ${#occupied[@]} -eq 0 ]] && exit 0

        # Build ordered list of all 50 desktops
        all=()
        for ((r=1; r<=ROWS; r++)); do
            for ((c=1; c<=COLS; c++)); do
                all+=("${r}_${c}")
            done
        done

        idx=$(( (ROW - 1) * COLS + (COL - 1) ))
        total=$(( ROWS * COLS ))
        step=$([[ "$2" == "left" ]] && echo -1 || echo 1)

        for ((i=1; i<total; i++)); do
            cand_idx=$(( (idx + i * step + total) % total ))
            cand="${all[$cand_idx]}"
            for occ in "${occupied[@]}"; do
                if [[ "$cand" == "$occ" ]]; then
                    bspc desktop -f "$cand"
                    exit 0
                fi
            done
        done
        ;;

    polybar)
        # Streams "[row]  1  2  3  4  5" to Polybar
        render_bar() {
            get_coords
            local occ_list urg_list
            occ_list=" $(bspc query -D -d .occupied --names | tr '\n' ' ') "
            urg_list=" $(bspc query -D -d .urgent --names | tr '\n' ' ') "

            # Row indicator [n] in theme color
            local out="%{F#89adfa}[${ROW}]%{F-} "

            for ((c=1; c<=COLS; c++)); do
                local d="${ROW}_${c}"
                local click="%{A1:bspc desktop -f $d:}"
                local end_click="%{A}"

                if [[ "$c" -eq "$COL" ]]; then
                    # Focused column: white text + theme underline
                    out+="${click}%{F#ffffff}%{u#89adfa}%{+u}  ${c}  %{-u}%{F-}${end_click}"
                elif [[ "$urg_list" == *" $d "* ]]; then
                    # Urgent column
                    out+="${click}%{B#9b0a20}%{F#ffffff}  ${c}  %{B-}%{F-}${end_click}"
                elif [[ "$occ_list" == *" $d "* ]]; then
                    # Occupied column
                    out+="${click}%{F#ffffff}  ${c}  %{F-}${end_click}"
                else
                    # Empty column (dimmed; set to out+="" if you want empty hidden)
                    out+="${click}%{F#555555}  ${c}  %{F-}${end_click}"
                fi
            done
            echo "$out"
        }

        render_bar
        bspc subscribe desktop_focus node_add node_remove node_transfer desktop_layout | while read -r _; do
            render_bar
        done
        ;;

    overview)
        # 10x5 interactive Rofi spatial grid
        get_coords
        declare -A win_summary
        for d in $(bspc query -D -d .occupied --names); do
            classes=()
            for nid in $(bspc query -N -d "$d" -n .window); do
                cls=$(xprop -id "$nid" WM_CLASS 2>/dev/null | awk -F'"' '{print $4}')
                [[ -n "$cls" ]] && classes+=("$cls")
            done
            win_summary["$d"]="${classes[*]}"
        done

        entries=()
        active_indices=()
        selected_idx=$(( (ROW - 1) * COLS + (COL - 1) ))

        idx=0
        for ((r=1; r<=ROWS; r++)); do
            for ((c=1; c<=COLS; c++)); do
                d="${r}_${c}"
                summary="${win_summary[$d]:--}"
                entries+=("[${r}:${c}] ${summary}")
                [[ -n "${win_summary[$d]}" ]] && active_indices+=("$idx")
                ((idx++))
            done
        done

        active_arg=()
        if [[ ${#active_indices[@]} -gt 0 ]]; then
            IFS=,; active_arg=(-a "${active_indices[*]}"); unset IFS
        fi

        choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i \
            -p "Workspace Grid" \
            -selected-row "$selected_idx" \
            -u "$selected_idx" \
            "${active_arg[@]}" \
            -theme-str 'window { width: 80%; } listview { columns: 5; lines: 10; flow: horizontal; fixed-columns: true; } element-text { horizontal-align: 0.0; }')

        if [[ "$choice" =~ ^\[([0-9]+):([0-9]+)\] ]]; then
            bspc desktop -f "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
        fi
        ;;
esac
