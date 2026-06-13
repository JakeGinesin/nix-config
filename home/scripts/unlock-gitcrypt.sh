#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-$HOME/nix-cfg}"
KEY="$(mktemp)"
trap 'shred -u "$KEY"' EXIT
agenix -d "$REPO/secrets/git-crypt.age" -i "$HOME/.ssh/id_ed25519" > "$KEY"
git -C "$REPO" crypt unlock "$KEY"
echo "Unlocked $REPO"
