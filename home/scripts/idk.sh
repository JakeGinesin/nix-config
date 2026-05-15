add_idk() {
  if [[ "$1" == "" ]]; then
    echo "Empty entry"
    exit 0
  fi
  fq=$(rg "$1" /home/synchronous/journal/rest/idk.md 2> /dev/null)
  if [[ "$fq" != "" ]]; then
    echo "Entry already present"
    exit 0
  fi
  echo "- $1" >> /home/synchronous/journal/rest/idk.md
  echo "Added entry: '$1'"
  idk_len=$(wc -l /home/synchronous/journal/rest/idk.md | awk '{print $1}')
  echo "You do not know $idk_len things!"
}

run_command() {
  case $1 in
    "add") add_idk "$2" ;;
    "del") remove_idk "$2" ;;
    *)
  esac
}

run_command "$1" "$2"
