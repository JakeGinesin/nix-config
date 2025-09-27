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

# Autoformat your nix files
alejandra . &>/dev/null \
  || ( alejandra . ; echo "formatting failed!" && exit 1)

prev=$(hostname)

sudo /run/current-system/sw/bin/nixos-rebuild switch --flake /home/synchronous/nix-cfg/flake.nix#"$prev" 2>&1 | tee /tmp/nixos-switch.log

notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
