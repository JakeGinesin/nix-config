#!/usr/bin/env bash
# designed to compile tex with isolation, in the case something like minted is used
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <texfile> [tectonic args...]"
  exit 1
fi

TEXFILE="$1"
shift

mkdir -p ~/.cache/Tectonic

nix-shell -p bubblewrap tectonic cacert python313Packages.pygments which --run "
  bwrap --ro-bind /nix /nix \
        --bind \$(pwd) /workspace \
        --bind ~/.cache/Tectonic ~/.cache/Tectonic \
        --chdir /workspace \
        --dev /dev \
        --proc /proc \
        --tmpfs /tmp \
        --symlink \$(which bash) /bin/sh \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --ro-bind /etc/hosts /etc/hosts \
        --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
        --setenv SSL_CERT_FILE \"\$SSL_CERT_FILE\" \
        --setenv TMPDIR /tmp \
        --setenv PATH \"\$PATH\" \
        tectonic -Z shell-escape '$TEXFILE' --keep-intermediates $*
"
