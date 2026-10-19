#!/usr/bin/env bash

ROWS=10
COLS=5

init_grid() {
    local mon="${1:-$(bspc query -M -m focused --names)}"
    local max_r="${2:-$ROWS}"
    local desks=()
    for ((r=1; r<=max_r; r++)); do
        for ((c=1; c<=COLS; c++)); do
            desks+=("${r}_${c}")
        done
    done
    bspc monitor "$mon" -d "${desks[@]}"
    for old in $(seq 1 20) Desktop; do
        bspc desktop "$old" -r 2>/dev/null
    done
}

get_coords() {
    local cur
    cur=$(bspc query -D -d focused --names)
    if [[ "$cur" =~ ^([0-9]+)_([0-9]+)$ ]]; then
        ROW="${BASH_REMATCH[1]}"
        COL="${BASH_REMATCH[2]}"
    else
        init_grid
        ROW=1
        COL=1
    fi
}

apply_target() {
    local mode="$1" target="$2"
    case "$mode" in
        focus)  bspc desktop -f "$target" ;;
        send)   bspc node -d "$target" ;;
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
        init_grid "$2" "$3"
        ;;

    col-focus|col-send|col-swap)
        get_coords
        apply_target "${1#col-}" "${ROW}_${2}"
        ;;

    row-focus|row-send|row-swap)
        get_coords
        apply_target "${1#row-}" "${2}_${COL}"
        ;;

    step-row-focus|step-row-send)
        get_coords
        if [[ "$2" == "up" ]]; then
            next_r=$(( ROW % ROWS + 1 ))
        else
            next_r=$(( (ROW - 2 + ROWS) % ROWS + 1 ))
        fi
        apply_target "${1#step-row-}" "${next_r}_${COL}"
        ;;

    step-col-focus|step-col-send)
        get_coords
        if [[ "$2" == "left" ]]; then
            next_c=$(( COL % COLS + 1 ))
        else
            next_c=$(( (COL - 2 + COLS) % COLS + 1 ))
        fi
        apply_target "${1#step-col-}" "${ROW}_${next_c}"
        ;;

    fast-shift)
        # Only cycle occupied desktops within the current row [ROW]
        get_coords
        step=$([[ "$2" == "left" ]] && echo -1 || echo 1)
        for ((i=1; i<COLS; i++)); do
            cand_c=$(( (COL - 1 + i * step + COLS) % COLS + 1 ))
            cand="${ROW}_${cand_c}"
            if [[ -n "$(bspc query -N -d "$cand" -n .window)" ]]; then
                bspc desktop -f "$cand"
                exit 0
            fi
        done
        ;;

    polybar)
        render_bar() {
            get_coords
            local occ_list urg_list
            occ_list=" $(bspc query -D -d .occupied --names | tr '\n' ' ') "
            urg_list=" $(bspc query -D -d .urgent --names | tr '\n' ' ') "

            local out="%{F#89adfa}[${ROW}]%{F-} "

            for ((c=1; c<=COLS; c++)); do
                local d="${ROW}_${c}"
                local click="%{A1:bspc desktop -f $d:}"
                local end_click="%{A}"

                if [[ "$c" -eq "$COL" ]]; then
                    out+="${click}%{F#ffffff}%{u#89adfa}%{+u}  ${c}  %{-u}%{F-}${end_click}"
                elif [[ "$urg_list" == *" $d "* ]]; then
                    out+="${click}%{B#9b0a20}%{F#ffffff}  ${c}  %{B-}%{F-}${end_click}"
                elif [[ "$occ_list" == *" $d "* ]]; then
                    out+="${click}%{F#ffffff}  ${c}  %{F-}${end_click}"
                else
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
        # Desktop-only 10x5 grid overview
        get_coords
        occ_list=" $(bspc query -D -d .occupied --names | tr '\n' ' ') "

        entries=()
        active_indices=()
        selected_idx=$(( (ROW - 1) * COLS + (COL - 1) ))

        idx=0
        for ((r=1; r<=ROWS; r++)); do
            for ((c=1; c<=COLS; c++)); do
                d="${r}_${c}"
                entries+=("[${r}] ${c}")
                [[ "$occ_list" == *" $d "* ]] && active_indices+=("$idx")
                ((idx++))
            done
        done

        active_arg=()
        if [[ ${#active_indices[@]} -gt 0 ]]; then
            IFS=,; active_arg=(-a "${active_indices[*]}"); unset IFS
        fi

        choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i \
            -p "Desktops" \
            -selected-row "$selected_idx" \
            -u "$selected_idx" \
            "${active_arg[@]}" \
            -theme-str 'window { width: 45%; } listview { columns: 5; lines: 10; flow: horizontal; fixed-columns: true; } element-text { horizontal-align: 0.5; }')

        if [[ "$choice" =~ ^\[([0-9]+)\]\ ([0-9]+)$ ]]; then
            bspc desktop -f "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
        fi
        ;;
esac
