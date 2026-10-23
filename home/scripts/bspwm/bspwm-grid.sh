#!/usr/bin/env bash
# bspwm-grid: a ROWS x COLS desktop grid for bspwm.
#
# Each row remembers the column it was last on. Nothing runs in the
# background for this: the memory is written when you leave a row through
# this script, and by the polybar loop, which already wakes on focus changes.

ROWS=10
COLS=5

# One tiny file per row, e.g. $STATE_DIR/3 contains "4"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/bspwm-grid-$UID"

init_grid() {
    local mon="${1:-}" max_r="${2:-$ROWS}" desks=() r c old
    [[ -n "$mon" ]] || mon=$(bspc query -M -m focused --names)
    for ((r=1; r<=max_r; r++)); do
        for ((c=1; c<=COLS; c++)); do
            desks+=("${r}_${c}")
        done
    done
    bspc monitor "$mon" -d "${desks[@]}"
    for old in {1..20} Desktop; do
        bspc desktop "$old" -r 2>/dev/null || true
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

# remember ROW COL: row ROW was last on column COL (shell builtins only)
remember() {
    [[ -d "$STATE_DIR" ]] || mkdir -p "$STATE_DIR"
    echo "$2" > "$STATE_DIR/$1"
}

# recall ROW: print the column ROW was last on, or the current column
recall() {
    local c=""
    if [[ -r "$STATE_DIR/$1" ]]; then
        read -r c < "$STATE_DIR/$1" || true
    fi
    if [[ "$c" =~ ^[1-9][0-9]*$ ]] && (( c <= COLS )); then
        echo "$c"
    else
        echo "$COL"
    fi
}

# " name1 name2 " for desktops matching a descriptor (bspc fails on no match)
names_matching() {
    local list
    list=$(bspc query -D -d "$1" --names 2>/dev/null || true)
    echo " ${list//$'\n'/ } "
}

apply_target() {
    local mode="$1" target="$2" cur
    case "$mode" in
        focus)  bspc desktop -f "$target" ;;
        send)   bspc node -d "$target" ;;
        follow) bspc node -d "$target" --follow ;;
        swap)
            cur=$(bspc query -D -d focused --names)
            if [[ "$target" == "$cur" ]]; then
                exit 0
            fi
            bspc desktop "$target" -n tmp_swap
            bspc desktop "$cur" -s tmp_swap
            bspc desktop "$cur" -n "$target"
            bspc desktop tmp_swap -n "$cur"
            ;;
    esac
}

case "${1:-}" in
    init)
        init_grid "${2:-}" "${3:-}"
        ;;

    col-focus|col-send|col-swap)
        get_coords
        apply_target "${1#col-}" "${ROW}_${2:?missing column}"
        ;;

    row-focus|row-send|row-swap)
        get_coords
        if [[ "$1" == "row-swap" ]]; then
            # Swapping stays positional: same column in the target row
            apply_target swap "${2:?missing row}_${COL}"
        else
            remember "$ROW" "$COL"
            apply_target "${1#row-}" "${2:?missing row}_$(recall "$2")"
        fi
        ;;

    step-row-focus|step-row-send)
        get_coords
        if [[ "${2:-}" == "up" ]]; then
            next_r=$(( ROW % ROWS + 1 ))
        else
            next_r=$(( (ROW - 2 + ROWS) % ROWS + 1 ))
        fi
        remember "$ROW" "$COL"
        apply_target "${1#step-row-}" "${next_r}_$(recall "$next_r")"
        ;;

    step-col-focus|step-col-send)
        get_coords
        if [[ "${2:-}" == "left" ]]; then
            next_c=$(( (COL - 2 + COLS) % COLS + 1 ))
        else
            next_c=$(( COL % COLS + 1 ))
        fi
        apply_target "${1#step-col-}" "${ROW}_${next_c}"
        ;;

    fast-shift)
        # Only cycle occupied desktops within the current row [ROW]
        get_coords
        if [[ "${2:-}" == "left" ]]; then step=-1; else step=1; fi
        for ((i=1; i<COLS; i++)); do
            cand="${ROW}_$(( (COL - 1 + i * step + COLS) % COLS + 1 ))"
            if [[ -n "$(bspc query -N -d "$cand" -n .window 2>/dev/null)" ]]; then
                bspc desktop -f "$cand"
                exit 0
            fi
        done
        ;;

    polybar)
        # Absolute path so click actions work even when polybar runs with a
        # minimal PATH (e.g. home-manager's polybar service)
        BSPC=$(command -v bspc)

        render_bar() {
            local occ_list urg_list out c d click end_click
            get_coords
            # Free piggyback: this loop already wakes on every focus change
            remember "$ROW" "$COL"
            occ_list=$(names_matching .occupied)
            urg_list=$(names_matching .urgent)

            out="%{F#89adfa}[${ROW}]%{F-} "

            for ((c=1; c<=COLS; c++)); do
                d="${ROW}_${c}"
                click="%{A1:$BSPC desktop -f $d:}"
                end_click="%{A}"

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
        # Desktop-only grid overview
        get_coords
        occ_list=$(names_matching .occupied)

        entries=()
        active_indices=()
        selected_idx=$(( (ROW - 1) * COLS + (COL - 1) ))

        idx=0
        for ((r=1; r<=ROWS; r++)); do
            for ((c=1; c<=COLS; c++)); do
                entries+=("[${r}] ${c}")
                if [[ "$occ_list" == *" ${r}_${c} "* ]]; then
                    active_indices+=("$idx")
                fi
                idx=$(( idx + 1 ))
            done
        done

        active_arg=()
        if (( ${#active_indices[@]} > 0 )); then
            IFS=,; active_arg=(-a "${active_indices[*]}"); unset IFS
        fi

        choice=$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i \
            -p "Desktops" \
            -selected-row "$selected_idx" \
            -u "$selected_idx" \
            "${active_arg[@]}" \
            -theme-str 'window { width: 45%; } listview { columns: 5; lines: 10; flow: horizontal; fixed-columns: true; } element-text { horizontal-align: 0.5; }') \
            || exit 0

        if [[ "$choice" =~ ^\[([0-9]+)\]\ ([0-9]+)$ ]]; then
            remember "$ROW" "$COL"
            bspc desktop -f "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
        fi
        ;;

    *)
        echo "usage: bspwm-grid {init|col-*|row-*|step-row-*|step-col-*|fast-shift|polybar|overview} [arg]" >&2
        exit 1
        ;;
esac
