#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$HOME/nix-cfg}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

for cmd in git-crypt agenix git; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd not in PATH" >&2; exit 1; }
done
[[ -f "$SSH_KEY" ]]                       || { echo "error: missing $SSH_KEY" >&2; exit 1; }
[[ -d "$REPO/.git" ]]                     || { echo "error: $REPO is not a git repo" >&2; exit 1; }
[[ -f "$REPO/secrets/git-crypt.age" ]]    || { echo "error: no git-crypt.age in $REPO/secrets" >&2; exit 1; }

# key never touches disk — process substitution feeds it directly
git -C "$REPO" crypt unlock <(cd "$REPO/secrets" && agenix -d git-crypt.age -i "$SSH_KEY")
echo "unlocked $REPO"
