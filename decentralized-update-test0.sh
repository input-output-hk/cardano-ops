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
    nixops ssh $f "mkdir -p /root/keys/"
    nixops scp $f keys/utxo-keys/utxo$BFTI.vkey /root/keys/utxo.vkey --to
    nixops scp $f keys/utxo-keys/utxo$BFTI.skey /root/keys/utxo.skey --to
    nixops scp $f keys/delegate-keys/delegate$BFTI.vkey /root/keys/delegate.vkey --to
    nixops scp $f keys/delegate-keys/delegate$BFTI.skey /root/keys/delegate.skey --to
    nixops scp $f keys/genesis-keys/genesis$BFTI.vkey /root/keys/genesis.vkey --to
    nixops scp $f keys/genesis-keys/genesis$BFTI.skey /root/keys/genesis.skey --to
    ((BFTI++))
done

for f in $POOL_NODES
do
    # TODO: we copy all keys for now.
    echo "TODO..."
done

for f in $BFT_NODES
do
    nixops ssh $f < submit-update-proposal.sh
done


./register-stake-pool.sh 1
