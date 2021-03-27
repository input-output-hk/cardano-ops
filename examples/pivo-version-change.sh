#!/usr/bin/env bash
#
# This test script registers stakepools, submits an update proposal, and have
# the stake holders voting on it so that it is approved.
#
# This script requires the following environment variables to be defined:
#
# - BFT_NODES: names of the BFT nodes
# - POOL_NODES: names of the stake pool nodes
#
set -euo pipefail

[ -z ${BFT_NODES+x} ] && (echo "Environment variable BFT_NODES must be defined"; exit 1)
[ -z ${POOL_NODES+x} ] && (echo "Environment variable POOL_NODES must be defined"; exit 1)

if [ -z ${1+x} ];
then
    echo "'redeploy' command was not specified, so the test will run on an existing testnet";
else
    case $1 in
        redeploy )
            echo "Redeploying the testnet"
            nixops destroy
            ./scripts/create-shelley-genesis-and-keys.sh
            nixops deploy -k
            ;;
        * )
            echo "Unknown command $1"
            exit
    esac
fi

# fixme: we might not need the BFT_NODES environment variable.
BFT_NODES=($BFT_NODES)
POOL_NODES=($POOL_NODES)

# Copy the scripts to the pool nodes
for f in ${POOL_NODES[@]}
do
    nixops scp $f examples/pivo-version-change/lib.sh /root/ --to
    nixops scp $f examples/pivo-version-change/run.sh /root/ --to
done

# Register the stake pools
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh register" &
done

wait
echo "Stake pool registration exit code: $?"
# TODO: we should detect if any of the stake pool registration commands failed.
echo "Stake pools registered"

# You can query the blocks produced by each stakepool by running:
#
#   cardano-cli query ledger-state --testnet-magic 42 --shelley-mode | jq '.blocksCurrent'
#

################################################################################
## Submit the SIP
################################################################################
echo "Submitting an SIP commit using ${POOL_NODES[0]}"
nixops ssh ${POOL_NODES[0]} "./run.sh scommit"

################################################################################
## Reveal the SIP
################################################################################
# Wait till the submission is stable in the chain. This depends on the global
# parameters of the era. More specifically:
#
# - activeSlotsCoeff
# - securityParam
# - slotLength
#
# Ideally the values of these parameters should be retrieved from the node. For
# simplicity we use the values of the test genesis file, however there is no
# sanity check that the values assumed in this script are correct.
#
# We assume:
#
# - activeSlotsCoeff = 0.1
# - securityParam    = 10
# - slotLength       = 0.2
#
# So we have:
#
# - stabilityWindow = (3 * securityParam) / activeSlotsCoeff = (3 * 10) / 0.1 = 300
#
# We assume (according to the values of the genesis file) that a slot occurs
# every 0.2 seconds, so we need to wait for 300 * 0.2 = 60 seconds. In practice
# we add a couple of seconds to be on the safe side. In a proper test script we
# would ask the node when a given commit is stable on the chain.
echo "Submitting an SIP revelation using ${POOL_NODES[0]}"
sleep 65
nixops ssh ${POOL_NODES[0]} "./run.sh sreveal"

################################################################################
## Vote on the proposal
################################################################################
# We wait till the revelation is stable on the chain, which means that the
# voting period is open.
sleep 65
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh svote" &
done
wait

################################################################################
## Submit an implementation commit
################################################################################
sleep 10
nixops ssh ${POOL_NODES[0]} "./run.sh icommit"

################################################################################
## Reveal the implementation
################################################################################
# Wait till the SIP vote period ends, so that votes are tallied and the SIP is
# marked as approved.
sleep 180
nixops ssh ${POOL_NODES[0]} "./run.sh ireveal"

################################################################################
## Vote on the implementation
################################################################################
sleep 65
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh ivote" &
done
wait

################################################################################
## Endorse the implementation
################################################################################
# Wait till the end of the voting period is stable
sleep 180
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh endorse" &
done
wait
