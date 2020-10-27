#!/bin/bash

# TODO's:
#
# - [ ] parametrize the key locations and utxo we will use.
# - [ ] we need to wait till the transaction is accepted so that
#       `payment-tx-in` has a value.

# Check the initial funds. Needed only for debugging purposes.
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode

# Create a new payment address
cardano-cli shelley address key-gen \
            --verification-key-file payment.vkey \
            --signing-key-file payment.skey

# Create a new stake key pair
cardano-cli shelley stake-address key-gen \
            --verification-key-file stake.vkey \
            --signing-key-file stake.skey

## Use these keys to create a payment address:

cardano-cli shelley address build \
            --payment-verification-key-file payment.vkey \
            --stake-verification-key-file stake.vkey \
            --out-file payment.addr \
            --testnet-magic 42

# Get the transaction hash so that we can transfer funds to a newly created
# address.
cardano-cli shelley genesis initial-txin \
            --testnet-magic 42 \
            --verification-key-file utxo-keys/utxo1.vkey > initial-tx.hash

# Get the initial address from which we will transfer the funds
cardano-cli shelley genesis initial-addr \
            --testnet-magic 42 \
            --verification-key-file utxo-keys/utxo1.vkey > initial.addr

# Create the transaction, we assume the fees are 0, and set a long time to live
# to avoid having to add logic for querying the current blockchain tip.
cardano-cli shelley transaction build-raw \
            --tx-in $(cat initial-tx.hash) \
            --tx-out $(cat initial.addr)+3333333333333334 \
            --tx-out $(cat payment.addr)+10000000000000000 \
            --ttl 1000000 \
            --fee 0 \
            --out-file tx.raw

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file utxo-keys/utxo1.skey \
            --testnet-magic 42 \
            --out-file tx.signed

cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 --shelley-mode

# Balance checking
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat initial.addr)

cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat payment.addr)

# Register the stake address on the blockchain
cardano-cli shelley stake-address registration-certificate \
            --stake-verification-key-file stake.vkey \
            --out-file stake.cert

# Get the transaction input to which the funds were transferred to `payment.addr`.
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat payment.addr) \
            --out-file tmp.json
grep -oP '"\K[^"]+' -m 1 tmp.json | head -1 | tr -d '\n' > payment-tx-in

# We assume the fees and `keyDeposit` to be 0.
cardano-cli shelley transaction build-raw \
            --tx-in $(cat payment-tx-in) \
            --tx-out $(cat payment.addr)+10000000000000000 \
            --ttl 1000000 \
            --fee 0 \
            --out-file tx.raw \
            --certificate-file stake.cert

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file payment.skey \
            --signing-key-file stake.skey \
            --testnet-magic 42 \
            --out-file tx.signed

cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode

# Register a stakepool

# Generate cold keys and a cold counter
cardano-cli shelley node key-gen \
            --cold-verification-key-file cold.vkey \
            --cold-signing-key-file cold.skey \
            --operational-certificate-issue-counter-file cold.counter

# Genereate a VRF key pair
cardano-cli shelley node key-gen-VRF \
            --verification-key-file vrf.vkey \
            --signing-key-file vrf.skey

# Generate a KES Key pair
cardano-cli shelley node key-gen-KES \
            --verification-key-file kes.vkey \
            --signing-key-file kes.skey

# Generate an operational certificate
# We take the slots per KES period from the `genesis.json` file.
#
# TODO: we need a way to ensure consistency between
#
# We also need to know the current slot number:
SLOTS_PER_KES_PERIOD=129600
KES_PERIOD=`cardano-cli shelley query tip --testnet-magic 42 | jq '.slotNo' | xargs -I '{}' expr '{}' / 129600`
cardano-cli shelley node issue-op-cert \
            --kes-verification-key-file kes.vkey \
            --cold-signing-key-file cold.skey \
            --operational-certificate-issue-counter cold.counter \
            --kes-period $KES_PERIOD \
            --out-file node.cert
