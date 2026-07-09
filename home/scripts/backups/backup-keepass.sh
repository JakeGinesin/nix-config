#!/usr/bin/env zsh
set -euo pipefail
source /home/synchronous/.agenix/agenix/zsh_remote
restic -r sftp:${aliases[kubeserver]#ssh }:/home/synchronous/backups/keepass \
    backup /home/synchronous/.config/keep \
    --insecure-no-password
