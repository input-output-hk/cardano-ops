#!/usr/bin/env bash

set -euo pipefail

. lib.sh

# This script assumes a running testnet. See 'pivo-version-change.sh'.
CLI=cardano-cli
UTXO=keys/utxo

# Transfer funds from the initial genesis key
INITIAL_ADDR=initial.addr
$CLI -- genesis initial-addr \
     --testnet-magic 42 \
     --verification-key-file $UTXO.vkey > $INITIAL_ADDR

# Transaction submission loop.
#
# On each iteration we generate a new key and transfer a random small amount of
# ADA to this key from the initial address.
while true; do
    $CLI address key-gen \
         --verification-key-file key.vkey \
         --signing-key-file      key.skey

    $CLI address build \
         --payment-verification-key-file key.vkey \
         --out-file payment.addr \
         --testnet-magic 42

    # Amount we will be transferring in each transaction. We do not check at the
    # moment that the genesis utxo key has funds to cover this amount. Ideally, the
    # transfer amount should be a percentage of these initial funds.
    transfer_amount=$(( RANDOM % 100 + 1))

    submit_transaction \
        $INITIAL_ADDR \
        $INITIAL_ADDR \
        build-raw \
        "--tx-out $(cat payment.addr)+$transfer_amount" \
        "--signing-key-file $UTXO.skey" \
        --shelley-mode \
        $transfer_amount || exit 1

    # We query the utxo set to show that we added a new entry.
    $CLI query utxo --testnet-magic 42 --shelley-mode
    sleep 2
done
