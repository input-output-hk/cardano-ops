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

rm -fr utxo-keys/
mkdir utxo-keys/

threads=200
for i in $(seq 1 $threads); do
    # Create a spending key
    $CLI -- address key-gen \
         --verification-key-file utxo-keys/spending-key$i.vkey \
         --signing-key-file utxo-keys/spending-key$i.skey
    $CLI address build \
         --payment-verification-key-file utxo-keys/spending-key$i.vkey \
         --out-file utxo-keys/payment$i.addr \
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

nr_keys=$(ls -l utxo-keys/spending-key*.vkey | wc -l)
batch_size=200
batch=1
i=1
while [[ $i -le $nr_keys ]]; do
    n=0
    txouts=""
    while [[ $i -le $(($batch_size * $batch)) ]] && [[ $i -le $nr_keys ]]; do
        # We will use only one transaction to send funds from 'PAYMENT_ADDR' to
        # multiple addresses. We need to build the tx-out arguments.
        txouts=$txouts"--tx-out $(cat utxo-keys/payment$i.addr)+$amount "
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


# Another ugly hack: we clear the transaction logs
echo
echo "Clearing the logs"
echo
rm tx-submission.log
