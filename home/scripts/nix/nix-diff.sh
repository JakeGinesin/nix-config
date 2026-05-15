#!/usr/bin/env bash
# shows what changed between the current and previous NixOS generation

PROFILE="/nix/var/nix/profiles/system"

# current generation number from the profile symlink (e.g. system-185-link)
current_gen=$(readlink "$PROFILE" | grep -oP '\d+')
prev_gen=$((current_gen - 1))

current=$(readlink -f "${PROFILE}-${current_gen}-link")
previous=$(readlink -f "${PROFILE}-${prev_gen}-link")

if [ ! -e "${PROFILE}-${prev_gen}-link" ]; then
  echo "Previous generation ($prev_gen) not found (garbage collected?)."
  exit 1
fi

echo -e "\033[1mGen $prev_gen:\033[0m $previous"
echo -e "\033[1mGen $current_gen:\033[0m $current"
echo

if command -v nvd &>/dev/null; then
  nvd diff "$previous" "$current"
else
  nix store diff-closures "$previous" "$current"
fi
