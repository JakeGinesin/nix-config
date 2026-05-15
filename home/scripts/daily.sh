# get today's date
curr=$(date +%y-%m-%d)
curr_bigyear=$(date +%Y-%m-%d)
# echo "$curr"
curr_pretty=$(date "+%A, %B %d %G")
curr_onenumber=$(date +%Y%m%d)
echo "Today: $curr_pretty"

# get written journal lines
journal_len=$(wc /home/synchronous/journal/daily.md | awk '{print $1}')
journal_date_area=$(rg 25-12-03 /home/synchronous/journal/daily.md -n -o | sed 's/:/ /' | awk '{print $1}')
journal=""
if [[ $journal_date_area == "" ]]; then
  journal="No writing in the journal yet today.."
else
  jd_diff=$(echo "$journal_len - $journal_date_area" | bc)
  journal="You've written $jd_diff journal line(s)"
fi

# get todos for today
todo_len=$(awk '!NF { print NR; exit }' /home/synchronous/journal/todo.md)
todo_len_1=$(echo "$todo_len" - 1 | bc)
todo_len_2=$(echo "$todo_len" - 2 | bc)
todos=$(head /home/synchronous/journal/todo.md -n "$todo_len_1" | tail -n "$todo_len_2")

# choose idk based on psuedorandom seeded with date
idk_len=$(wc -l /home/synchronous/journal/rest/idk.md | awk '{print $1'})
idk_date=$(date +%Y%m%d)
idk_pseudo=$(python3 -c "import math; import random; random.seed($idk_date); print(  math.floor(random.random() * 10000) % $idk_len)")
idk=$(sed -n '7 p' /home/synchronous/journal/rest/idk.md | cut -c3-)

# check if there exists a .daily in home for this day
daily_date=$(stat -c "%y" /home/synchronous/.daily | awk '{print $1}')
if [[ $daily_date != $curr_bigyear ]]; then  
  rm /home/synchronous/.daily
  touch /home/synchronous/.daily

  # set idk
  echo "- idk: $idk" >> /home/synchronous/.daily
else
  idk_prev=$(rg idk /home/synchronous/.daily | cut -c8-) # take existing idk
  if [[ $idk_prev != $idk ]]; then
    idk="$idk_prev [done!]"
  fi
fi

echo 

# echo $idk

echo "Lore for today:"
echo "- idk: $idk"
echo "- $journal"

echo 

# TODOS SETUP
echo "Todos for today ($todo_len_2 items):"
echo "$todos"
