#!/usr/bin/env bash

set -euxo pipefail

cd "$(dirname "$0")/.."

# Credential setup
if [ ! -f ./static/graylog-creds.nix ]; then
  nix-shell -A gen-graylog-creds
fi

nixops destroy || true
nixops delete || true
nixops create ./deployments/cardano-aws.nix -I nixpkgs=./nix
nixops deploy --show-trace
