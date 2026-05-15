#!/usr/bin/env bash

main="/home/synchronous/journal"
#main_dir="$main/abstract"
#main="/home/synchronous/code/nm/notes"
main_dir="$main/rest"
rofi_prompt="/home/synchronous/.config/rofi/styles/prompt-search.rasi"
len_maindir=${#main_dir}

search() {
  rs="$(find "$main_dir" -follow -printf "%T@ %Tc %p\n" | sort -n -r | cut -c"$((len_maindir + 56))"- | rg -a '\.md$')"
  rcv=$(echo "$rs" | rofi -dmenu -theme "$rofi_prompt")
  if [[ "$rcv" == "" ]]; then exit 1; fi
  if [[ $(echo "$rs" | rg "$rcv") ]]; then # check if we actually have our note
    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | execute 'normal 4j' | set path+=$main_dir | set wrap | autocmd BufEnter * let b:coc_suggest_disable=1" &!
      # -c "lua vim.g.goyo_if = 1"
      # -c "syntax match LinkPattern /[a-zA-Z0-9\-][a-zA-Z0-9\-]*\.md/" \
      # -c "highlight LinkPattern guifg=LightBlue gui=underline" \
      # -c "nnoremap <CR> :call CustomGf()<CR>" \
      # -c "nnoremap gf :call CustomGf()<CR>" \
  else 

    # if rcv doesn't contain md, add it
    if [[ $(echo "$rcv" | rg -v '\.md$') ]]; then
      rcv="$rcv.md"
    fi

    no_md="${rcv%.md}"
    replaced="${no_md//[-_]/ }"
    # echo "lol"

    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | set path+=$main_dir | set wrap | autocmd BufEnter * let b:coc_suggest_disable=1" \
      -c "call setline(1, ['---', 'title: $replaced', 'tags: ', '---', '']) | execute 'normal G'" &!
          # make sure standardized frontmatter is there
  fi
}

open_daily() {
  alacritty -t "daily.md" -e nvim "$main/daily.md" \
    -c "Goyo | set wrap | set path+=$main_dir" \
    -c "execute 'normal G'" \
    -c "lua vim.g.goyo_if = 1" &!
}

open_idk() {
  alacritty -t "idk.md" -e nvim "$main/rest/idk.md" \
    -c "Goyo | set wrap | set path+=$main_dir" \
    -c "execute 'normal G'" \
    -c "lua vim.g.goyo_if = 1" &!
}

open_todo() {
  alacritty -t "todo.md" -e nvim "$main/todo.md" \
    -c "execute 'lua vim.g.goyo_if = 1' | set wrap | Goyo | set path+=$main_dir" &!
    # -c "execute 'normal G'"
}

notes_find() {
  rg $2 $main_dir
}

search_by_tags() {
  tt=""
  # while IFS= read -r -d '' file; do
      # is_tags=$(awk 'NR==3 {print substr($0, 1, 4)}' "$file")
      # if [[ $is_tags == "tags" ]]; then
          # line=$(sed -n '3p' "$file")
          # tt+=$(echo "$file" | cut -c"$((len_maindir + 2))"- )
          # tt+=" [$(echo "$line" | cut -c7-)]\n"
      # fi
  # done < <(find $main_dir -type f -print0)
  
  rs="$(find "$main_dir" -follow -printf "%T@ %Tc %p\n" | sort -n -r | cut -c"$((len_maindir + 49))"- | rg -a '\.md$')"

  while IFS= read -r -d '' file; do
    { read -r _; read -r _; read -r line; } < "$file"

    if [[ ${line:0:4} == "tags" ]]; then  
        tags="${line:6}"
        tags="${tags#"${tags%%[![:space:]]*}"}"
        tags="${tags%"${tags##*[![:space:]]}"}"
        filename="${file:$((len_maindir + 1))}"
        tt+="$filename [$tags]\n"
    fi
  done < <(find "$main_dir" -type f -print0)

  rcv=$(echo -e "$tt" | awk 'NR > 1 {print prev} {prev=$0} END {printf "%s", prev}' | rofi -dmenu -theme "$rofi_prompt")
  rcv=$(echo $rcv | sed 's/ \[[^]]*\]$//')
  if [[ "$rcv" == "" ]]; then exit 1; fi
  if [[ $(echo "$rs" | rg "$rcv") ]]; then # check if we actually have our note
    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | execute 'normal 4j' | set path+=$main_dir |  autocmd BufEnter * let b:coc_suggest_disable=1" &!
  else 

    # if rcv doesn't contain md, add it
    if [[ $(echo "$rcv" | rg -v '\.md$') ]]; then
      rcv="$rcv.md"
    fi

    no_md="${rcv%.md}"
    replaced="${no_md//[-_]/ }"

    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | set path+=$main_dir | autocmd BufEnter * let b:coc_suggest_disable=1" \
      -c "call setline(1, ['---', 'title: $replaced', 'tags: ', '---', '']) | execute 'normal G'" &! 
  fi
}

search_by_title() {
  # tt=""
  # while IFS= read -r -d '' file; do
      # is_title=$(awk 'NR==2 {print substr($0, 1, 5)}' "$file")
      # if [[ $is_title == "title" ]]; then
          # line=$(sed -n '2p' "$file")
          # # tt+="$(echo "$line" | cut -c7-)"
          # tt+="$(echo "$line" | cut -c7- | sed 's/^ *//; s/ *$//')"
          # tt+=' ('$(echo "$file" | cut -c"$((len_maindir + 2))"- )')\n'
      # fi
  # done < <(find $main_dir -type f -print0)

  rs="$(find "$main_dir" -follow -printf "%T@ %Tc %p\n" | sort -n -r | cut -c"$((len_maindir + 49))"- | rg -a '\.md$')"

  tt=""
  while IFS= read -r -d '' file; do
      { read -r _; read -r line; } < "$file"

      if [[ ${line:0:5} == "title" ]]; then  
          title="${line:6}"  

          title="${title#"${title%%[![:space:]]*}"}"
          title="${title%"${title##*[![:space:]]}"}"
          filename="${file:$((len_maindir + 1))}"
          tt+="$title ($filename)\n"
      fi
  done < <(find "$main_dir" -type f -print0)

  rcv=$(echo -e "$tt" | awk 'NR > 1 {print prev} {prev=$0} END {printf "%s", prev}' | rofi -dmenu -theme "$rofi_prompt")
  rcv=$(echo $rcv | rg -e "[a-zA-Z0-9]*\.md" -o)
  if [[ "$rcv" == "" ]]; then exit 1; fi
  # echo "$rcv"
  if [[ $(echo "$rs" | rg "$rcv") ]]; then # check if we actually have our note
    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | execute 'normal 4j' | set path+=$main_dir | autocmd BufEnter * let b:coc_suggest_disable=1" &!
  else 

    # if rcv doesn't contain md, add it
    if [[ $(echo "$rcv" | rg -v '\.md$') ]]; then
      rcv="$rcv.md"
    fi

    no_md="${rcv%.md}"
    replaced="${no_md//[-_]/ }"

    alacritty -t "$rcv" -e nvim "$main_dir/$rcv" \
      -c "execute 'lua vim.g.goyo_if = 1' | Goyo | set wrap | set path+=$main_dir | autocmd BufEnter * let b:coc_suggest_disable=1" \
      -c "call setline(1, ['---', 'title: $replaced', 'tags: ', '---', '']) | execute 'normal G'" &! 
  fi
}

open_misc() {
  tf=$(mktemp --suffix=.md)
  # sh -c keeps window open for nvim, then deletes file immediately on exit
  alacritty -t "scratch" -e sh -c "nvim '$tf' \
    -c 'execute \"lua vim.g.goyo_if = 1\" | Goyo | set wrap | autocmd BufEnter * let b:coc_suggest_disable=1'; \
    rm '$tf'" &!
}

run_command() {
  case $1 in
    "search") search ;;
    "daily") open_daily ;;
    "todo") open_todo ;;
    "idk") open_idk ;;
    "find") notes_find ;;
    "tags") search_by_tags ;;
    "title") search_by_title ;;
    "misc") open_misc ;;
    *)
  esac
}

run_command "$1"
