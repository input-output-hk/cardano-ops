#!/usr/bin/env bash
#
# This is a simple test that submits an update proposal so that stakepools can
# produce blocks, and registers stakepools.
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

BFT_NODES=($BFT_NODES)
POOL_NODES=($POOL_NODES)

for f in ${BFT_NODES[@]}
do
    nixops scp $f examples/shelley-testnet/scripts/submit-update-proposal.sh /root/ --to
done

for f in ${POOL_NODES[@]}
do
    nixops scp $f examples/shelley-testnet/scripts/register-stake-pool.sh /root/ --to
done

for f in ${BFT_NODES[@]}
do
    nixops ssh $f "./submit-update-proposal.sh"
done

for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./register-stake-pool.sh" &
done

wait
