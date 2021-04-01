#!/usr/bin/env bash

set -euo pipefail

nixops destroy --confirm
./scripts/create-shelley-genesis-and-keys.sh
nixops deploy -k
