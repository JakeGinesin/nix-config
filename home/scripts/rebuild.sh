#!/usr/bin/env bash
# blatently adapted from: https://gist.github.com/0atman/1a5133b842f929ba4c1e195ee67599d5

# set -e

# cd to your config dir
pushd /home/synchronous/nix-cfg

# early return if no changes are given
git --git-dir /home/synchronous/nix-cfg/.git add .
if git --git-dir /home/synchronous/nix-cfg/.git diff-index --quiet HEAD; then
    echo "No changes detected, exiting."
    popd
    exit 0
fi

# /run/current-system/sw/bin/nix flake check /home/synchronous/nix-cfg/ || { echo "Flake check failed. Exiting."; exit 1; }

# Autoformat your nix files
alejandra . &>/dev/null \
  || ( alejandra . ; echo "formatting failed!" && exit 1)

# shows changes between last commit and head

# git --git-dir /home/synchronous/nix-cfg/.git add .
# git --git-dir /home/synchronous/nix-cfg/.git --no-pager diff -U0 
git --git-dir /home/synchronous/nix-cfg/.git --no-pager diff HEAD -U0 
# '*.nix'

echo ""
echo "Summary:"
git status --porcelain

echo ""
echo "NixOS Rebuilding..."

# brain damaged method
# prev=$(basename $(readlink /run/current-system) | sed 's/.*nixos-system-\(.*\)-.*$/\1/')
prev=$(hostname)

# Rebuild, output simplified errors, log trackebacks
sudo /run/current-system/sw/bin/nixos-rebuild switch --flake /home/synchronous/nix-cfg/flake.nix#"$prev" 2>&1 | tee /tmp/nixos-switch.log

# cat /tmp/nixos-switch.log | grep --color error && exit 1

if grep --color error /tmp/nixos-switch.log; then
    # cat /tmp/nixos-switch.log | grep --color error
    read -p "Would you like to view the error log? (y/n): " choice
    choice=${choice:-n}
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      cat /tmp/nixos-switch.log
    fi
    exit 1;
fi

# Get current generation metadata
# current=$(nixos-rebuild list-generations | grep current)
# current=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -n 1 | awk '{print $1, $2, $3}')
current=$(nixos-rebuild list-generations --json | jq -r '.[1] | [.generation, .buildDate, .nixosVersion, .kernelVersion, (.current|tostring)] | @tsv' | awk '{print "generation", $1, $2}')

# Commit all changes witih the generation metadata
git --git-dir /home/synchronous/nix-cfg/.git add .
git --git-dir /home/synchronous/nix-cfg/.git commit -am "$current"

# Back to where you were
popd

# rm /tmp/nixos-switch.log

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available

echo ""
echo "Full rebuild log in /tmp/nixos-switch.log"
