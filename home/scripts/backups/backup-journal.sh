#!/usr/bin/env zsh
set -eo pipefail
source /home/synchronous/.agenix/agenix/zsh_remote
restic -r sftp:${aliases[kubeserver]#ssh }:/home/synchronous/backups/journal \
    --password-file /home/synchronous/.agenix/agenix/restic-password \
    backup /home/synchronous/journal

# restic -r sftp:${aliases[kubeserver]#ssh }:/home/synchronous/backups/journal backup /home/synchronous/journal
