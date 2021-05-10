#!/usr/bin/env bash

set -euo pipefail

. lib.sh

# This script assumes a running testnet. See 'pivo-version-change.sh'.
CLI=cardano-cli
UTXO=keys/utxo

mkdir -p keys
rm -f keys/spending*
rm -f keys/payment*

echo
echo "Creating spending keys"
echo

threads=1000
for i in $(seq 1 $threads); do
    # Create a spending key
    $CLI -- address key-gen \
         --verification-key-file keys/spending-key$i.vkey \
         --signing-key-file keys/spending-key$i.skey
    $CLI address build \
         --payment-verification-key-file keys/spending-key$i.vkey \
         --out-file keys/payment$i.addr \
         --testnet-magic 42
done

echo
echo "Spending keys created"
echo

# Funds will be transferred from the initial genesis key to the keys created
# above. Then these keys will transfer funds in parallel to newly created keys,
# which will in turn repeat this process.
INITIAL_ADDR=initial.addr
$CLI -- genesis initial-addr \
     --testnet-magic 42 \
     --verification-key-file $UTXO.vkey > $INITIAL_ADDR

echo
echo "Transferring funds from initial address: $INITIAL_ADDR"
echo

# This snippet is taken from 'run.sh::transfer_funds' if these scripts are
# evolved further it'd might make sense to factor out common functionality.
amount=37

nr_keys=$(ls -l keys/spending-key*.vkey | wc -l)
batch_size=200
batch=1
i=1
while [[ $i -le $nr_keys ]]; do
    n=0
    txouts=""
    while [[ $i -le $(($batch_size * $batch)) ]] && [[ $i -le $nr_keys ]]; do
        # We will use only one transaction to send funds from 'PAYMENT_ADDR' to
        # multiple addresses. We need to build the tx-out arguments.
        txouts=$txouts"--tx-out $(cat keys/payment$i.addr)+$amount "
        n=$((n + 1))
        i=$((i + 1))
    done
    total=$(($amount*$n))
    submit_transaction \
        $INITIAL_ADDR \
        $INITIAL_ADDR \
        build-raw \
        "$txouts" \
        "--signing-key-file $UTXO.skey" \
        --shelley-mode \
        $total
    batch=$((batch + 1))
done

echo
echo "Funds transferred from initial address: $INITIAL_ADDR"
echo

create_new_key_and_pay_to_it(){
    $CLI address key-gen \
         --verification-key-file new-keys/spending-key$1.vkey \
         --signing-key-file      new-keys/spending-key$1.skey

    $CLI address build \
         --payment-verification-key-file new-keys/spending-key$1.vkey \
         --out-file new-keys/payment$1.addr \
         --testnet-magic 42

    echo
    echo "💸 Transferring $amount Lovelace to $(cat keys/payment$1.addr)"
    echo

    # Note that we transfer the total balance in 'keys/payment$1.addr' to the
    # new address.
    submit_transaction \
        keys/payment$1.addr \
        new-keys/payment$1.addr \
        build-raw \
        "" \
        "--signing-key-file keys/spending-key$1.skey" \
        --shelley-mode || exit 1

}

# Transaction submission loop.
nr_keys=$(ls -l keys/spending-key*.vkey | wc -l)
# At each iteration, each process 'i' will create a new key and trasfer funds
# from 'keys/spending-keyi' to 'new-keys/spending-keyi'. At the end of each
# iteration we move the spending keys in 'new-keys' over to 'keys'.
mkdir -p new-keys
while true; do
    echo
    echo "Submitting transactions in parallel"
    echo

    for i in $(seq 1 $nr_keys); do
       create_new_key_and_pay_to_it $i &
    done
    wait

    echo
    echo "Parallel transactions submitted"
    echo

    rm keys/spending-key*
    mv new-keys/spending-key* keys/

    rm keys/payment*
    mv new-keys/payment* keys/
done
