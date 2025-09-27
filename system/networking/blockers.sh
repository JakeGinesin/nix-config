# websites i'd like to (automatically) block on certain wifi connections
set -euo pipefail

blacklist=(
  "NUwave"
  "BostonPublicLibrary"
  "CMU-SECURE"
)

should_block=false
for ssid in "${blacklist[@]}"; do
  if [[ "$CONNECTION_ID" == "$ssid" ]]; then
    should_block=true
    break
  fi
done

# echo "$2, $CONNECTION_ID, $should_block" >> /home/synchronous/lol

if [[ "$should_block" == "false" ]]; then
  exit 1
fi

websites=(
  "www.reddit.com"
  "www.youtube.com"
  "www.instagram.com"
  "www.facebook.com"
  "facebook.com"
  "www.craigslist.org"
  "www.ebay.com"
  "www.monkeytype.com"
  "www.typeracer.com"
  "www.twitter.com"
  "www.linkedin.com"
  "www.chess.com"
  "www.x.com"
  "x.com"
  "news.ycombinator.com"
  "linkedin.com"
)

op=""
if [ "$2" == "up" ]; then
  op="on"
elif [ "$2" == "down" ]; then
  op="off"
else
  exit 0
fi

for website in "${websites[@]}"; do
  /run/current-system/sw/bin/bash /etc/profiles/per-user/synchronous/bin/dnsblock-norestart "$op" "$website" 
done

systemctl restart dnsmasq
