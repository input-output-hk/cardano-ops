#!/bin/bash

# TODO: destroy the deployment.
#
# nixops destroy

# TODO: create genesis file and keys
#
# create-shelley-genesis-and-keys
#
# TODO: this command should be run at deploment time.

# TODO: deploy
#
# nixops deploy -k

# TODO: can we get this from the nix files?
BFT_NODES=( bft-a-1 )
POOL_NODES=( stk-d-1-IOHK1 )

BFTI=1
for f in $BFT_NODES
do
    # Copy the script that we have to run
    nixops scp $f submit-update-proposal.sh /root/ --to
    ((BFTI++))
done

for f in $POOL_NODES
do
    # TODO: we copy all keys for now.
    echo "TODO..."
done

for f in $BFT_NODES
do
    nixops ssh $f "./submit-update-proposal.sh"
    echo $?
done

./register-stake-pool.sh 1
