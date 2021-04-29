#!/usr/bin/env bash
#
# See 'pivo-version-change.sh' for more information on this script.

set -euo pipefail

[ -z ${POOL_NODES+x} ] && (echo "Environment variable POOL_NODES must be defined"; exit 1)

CLI=cardano-cli

. $(dirname $0)/pivo-version-change/lib.sh

if [ -z ${1+x} ];
then
    echo "'redeploy' command was not specified, so the test will run on an existing testnet";
else
    case $1 in
        redeploy )
            echo "Redeploying the testnet"
            nixops destroy --confirm
            ./scripts/create-shelley-genesis-and-keys.sh
            nixops deploy -k
            ;;
        * )
            echo "Unknown command $1"
            exit
    esac
fi

POOL_NODES=($POOL_NODES)

# Copy the scripts to the pool nodes
for f in ${POOL_NODES[@]}
do
    nixops scp $f examples/pivo-version-change/lib.sh /root/ --to
    nixops scp $f examples/pivo-version-change/run.sh /root/ --to
done

clear

# Register the stake pool.
#
# We need a registered stake pool so that we can delegate stake to it.
# Otherwise the stake keys do not count as active stake.
# Register the stake pools
echo
echo "Registering stake pools"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh register" &
done
wait
echo
echo "Stake pools registered"
echo

# Create one payment key and one stake key per-participant
echo
echo "Creating payment and staking keys"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh ckeys 10000" &
done
wait
echo
echo "Payment and staking keys created"
echo

# Transfer the funds the node controls to each of the keys created above
echo
echo "Transfering funds"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh tfunds" &
done
wait
echo
echo "Funds transfered"
echo

# Register a stake key for each of the spending keys created above.
echo
echo "Registering stake keys"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh regkey" &
done
wait
echo
echo "Stake keys registered"
echo

# Query the stake distribution snapshots
# > cardano-cli query ledger-state --testnet-magic 42 --pivo-era --pivo-mode | jq '.stateBefore.esSnapshots'

# Commit the SIP

# Reveal the SIP

# Vote on the SIP with all the stake keys created above
