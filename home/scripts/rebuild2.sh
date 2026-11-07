#!/usr/bin/env bash
# blatently adapted from: https://gist.github.com/0atman/1a5133b842f929ba4c1e195ee67599d5

set -o pipefail

cfg=/home/synchronous/nix-cfg
log=/tmp/nixos-switch.log
host=$(hostname)

# cd to your config dir
pushd "$cfg" >/dev/null || exit 1

# early return if no changes are given
git add .
if git diff-index --quiet HEAD; then
    echo "No changes detected, exiting."
    popd >/dev/null
    exit 0
fi

# /run/current-system/sw/bin/nix flake check "$cfg" || { echo "Flake check failed. Exiting."; exit 1; }

# Autoformat your nix files
# (the old `|| ( ... exit 1 )` only exited the subshell, so the script kept going)
if ! alejandra . &>/dev/null; then
    alejandra .
    echo "formatting failed!"
    exit 1
fi

# shows changes between last commit and head
git --no-pager diff HEAD -U0

echo ""
echo "Summary:"
git status --porcelain

echo ""
echo "NixOS Rebuilding..."

# Build as your normal user (the nix daemon does the work, no sudo needed).
# The result symlink goes in a temp dir so it never lands in the repo and gets committed.
outdir=$(mktemp -d)
trap 'rm -rf "$outdir"' EXIT

build_cmd=(
    nix-fast-build
    --flake "$cfg#nixosConfigurations.$host.config.system.build.toplevel"
    --out-link "$outdir/result"
)

# `script` gives nix-fast-build a real terminal so nom draws its live view,
# while still recording everything to the log file. SHELL is pinned to bash
# because `script` runs the command through $SHELL.
if ! SHELL="$BASH" script -qefc "${build_cmd[*]@Q}" "$log"; then
    echo ""
    echo "Build failed."
    read -rp "Would you like to view the error log? (y/n): " choice
    if [[ "${choice:-n}" == [yY] ]]; then
        cat "$log"
    fi
    exit 1
fi

# nix-fast-build names the link after the attribute it built, so glob for it
toplevel=$(readlink -f "$outdir"/result* 2>/dev/null)
if [[ ! -x "$toplevel/bin/switch-to-configuration" ]]; then
    echo "Couldn't find the built system in $outdir, not switching."
    exit 1
fi

echo ""
echo "Activating $toplevel"

# The same two steps `nixos-rebuild switch` does: register the generation, then switch to it
if ! { sudo nix-env --profile /nix/var/nix/profiles/system --set "$toplevel" &&
       sudo "$toplevel/bin/switch-to-configuration" switch; } 2>&1 | tee -a "$log"; then
    echo ""
    echo "Activation failed, see $log"
    exit 1
fi

# Get current generation metadata
current=$(nixos-rebuild list-generations --json | jq -r '.[1] | [.generation, .buildDate, .nixosVersion, .kernelVersion, (.current|tostring)] | @tsv' | awk '{print "generation", $1, $2}')

# Commit all changes with the generation metadata
git add .
git commit -am "$current"

# Back to where you were
popd >/dev/null

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available

echo ""
echo "Full rebuild log in $log"
