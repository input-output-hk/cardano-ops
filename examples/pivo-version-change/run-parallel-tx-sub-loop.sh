#!/usr/bin/env bash

set -euo pipefail

. lib.sh

# This script assumes a running testnet. See 'pivo-version-change.sh'.
CLI=cardano-cli

# We want to start logging the transactions in this process only.
rm -f tx-submission.log

# FIXME: this is brittle. It relies on amount having the same value. Use a common constant (function).
amount=37

create_new_key_and_pay_to_it(){
    $CLI address key-gen \
         --verification-key-file new-keys/spending-key$1.vkey \
         --signing-key-file      new-keys/spending-key$1.skey

    $CLI address build \
         --payment-verification-key-file new-keys/spending-key$1.vkey \
         --out-file new-keys/payment$1.addr \
         --testnet-magic 42

    echo
    echo "💸 Process $1 is transferring $amount Lovelace to $(cat utxo-keys/payment$1.addr)"
    echo

    # Note that we transfer the total balance in 'utxo-keys/payment$1.addr' to the
    # new address.
    submit_transaction \
        utxo-keys/payment$1.addr \
        new-keys/payment$1.addr \
        build-raw \
        "" \
        "--signing-key-file utxo-keys/spending-key$1.skey" \
        --shelley-mode || exit 1

}

# Transaction submission loop.
nr_keys=$(ls -l utxo-keys/spending-key*.vkey | wc -l)
# At each iteration, each process 'i' will create a new key and trasfer funds
# from 'utxo-keys/spending-keyi' to 'new-keys/spending-keyi'. At the end of each
# iteration we move the spending keys in 'new-keys' over to 'keys'.
mkdir -p new-keys
while true; do
    echo
    echo "Submitting transactions in parallel on $(date)"
    echo

    for i in $(seq 1 $nr_keys); do
       create_new_key_and_pay_to_it $i &
    done
    wait

    echo
    echo "Parallel transactions submitted on $(date)"
    echo

    rm utxo-keys/spending-key*
    mv new-keys/spending-key* utxo-keys/

    rm utxo-keys/payment*
    mv new-keys/payment* utxo-keys/
done
