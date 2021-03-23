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

for f in ${POOL_NODES[@]}
do
    nixops scp $f examples/pivo-version-change/*.sh /root/ --to
done

nixops ssh $POOL_NODES[1] "./run.sh register"
