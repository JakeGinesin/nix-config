rsem=$(find /home/synchronous/current-semester -follow -maxdepth 1 | cut -c36- | sed '/^[[:space:]]*$/d' | rofi -dmenu)

# Exit if nothing selected
[ -z "$rsem" ] && exit 0

# Get URL and open if it exists
url=$(yq -r ".url" "/home/synchronous/current-semester/$rsem/info.yaml")
[ -n "$url" ] && firefox "$url"
