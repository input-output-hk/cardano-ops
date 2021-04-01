#!/usr/bin/env bash
set -euo pipefail

. $(dirname $0)/lib.sh

nix-shell

# Run the transaction submission loop in one of the nodes
try_till_success \
  "nixops scp ${BFT_NODES[0]} examples/pivo-version-change/lib.sh /root/ --to"
# Once the above command succeeds, we know the node is available, no there's no
# need to retry the command below.
nixops scp ${BFT_NODES[0]} examples/pivo-version-change/run-ustate-monitoring.sh /root/ --to

nixops ssh ${BFT_NODES[0]} "./run-ustate-monitoring.sh"
