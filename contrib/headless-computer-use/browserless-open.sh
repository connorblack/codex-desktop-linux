#!/bin/bash
set -Eeuo pipefail

node_bin="/opt/codex-desktop/resources/node-runtime/bin/node"
if [ ! -x "$node_bin" ]; then
    node_bin="$(command -v node || true)"
fi

if [ -z "$node_bin" ]; then
    echo "codex-browserless-open: node runtime not found" >&2
    exit 0
fi

mkdir -p /tmp/codex-headless
nohup "$node_bin" /usr/local/lib/codex-headless/browserless-open.mjs "$@" >>/tmp/codex-headless/browserless-open.log 2>&1 &
