#!/usr/bin/env zsh
set -euo pipefail
source /home/synchronous/.agenix/agenix/zsh_remote

restic -r sftp:${aliases[kubeserver]#ssh }:/home/synchronous/backups/keepass \
    forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --keep-yearly 3 \
    --prune \
    --insecure-no-password

restic -r sftp:${aliases[kubeserver]#ssh }:/home/synchronous/backups/journal \
    --password-file /home/synchronous/.agenix/agenix/restic-password \
    forget \
    --keep-daily 30 \
    --keep-weekly 12 \
    --keep-monthly 24 \
    --keep-yearly 100 \
    --prune
