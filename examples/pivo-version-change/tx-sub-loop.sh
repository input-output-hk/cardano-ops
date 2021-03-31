#!/usr/bin/env bash

set -euo pipefail

. $(dirname $0)/lib.sh

# Run the transaction submission loop in one of the nodes
try_till_success \
    "nixops scp ${BFT_NODES[0]} examples/pivo-version-change/lib.sh /root/ --to"
nixops scp ${BFT_NODES[0]} examples/pivo-version-change/run-tx-sub-loop.sh /root/ --to

nixops ssh ${BFT_NODES[0]} "./run-tx-sub-loop.sh"
