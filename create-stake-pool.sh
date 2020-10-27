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

echo '{
  "name": "PriviPool",
  "description": "Priviledge Pool",
  "ticker": "TEST",
  "homepage": "https://ppp"
}' > pool-metadata.json

# Get the hash of the file:
METADATA_HASH=`cardano-cli shelley stake-pool metadata-hash --pool-metadata-file pool-metadata.json`

# Generate a stakepool registration certificate

# Pledge amount in Lovelace
PLEDGE=1000000
# Pool cost per-epoch in Lovelace
COST=1000
# Pool cost per epoch in percentage
MARGIN=0.1

cardano-cli shelley stake-pool registration-certificate \
            --cold-verification-key-file cold.vkey \
            --vrf-verification-key-file vrf.vkey \
            --pool-pledge $PLEDGE \
            --pool-cost $COST \
            --pool-margin $MARGIN \
            --pool-reward-account-verification-key-file stake.vkey \
            --pool-owner-stake-verification-key-file stake.vkey \
            --testnet-magic 42 \
            --metadata-url file://pool-metadata.json \
            --metadata-hash $METADATA_HASH \
            --out-file pool-registration.cert

# Generate a delegation certificate pledge
cardano-cli shelley stake-address delegation-certificate \
            --stake-verification-key-file stake.vkey \
            --cold-verification-key-file cold.vkey \
            --out-file delegation.cert

# Registering a stake pool requires a deposit, which is specified in the
# genesis file. Here we assume the deposit is 0.
POOL_DEPOSIT=0
FEE=0
BALANCE=`jq '.[].amount' /tmp/balance.json | xargs printf '%.0f\n'`
CHANGE=`expr $BALANCE - $POOL_DEPOSIT - $FEE`
TTL=1000000

# We need the transaction in which the funds were traesfered to `payment.addr`.
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat payment.addr) \
            --out-file /tmp/tx-info.json
TX_IN=`grep -oP '"\K[^"]+' -m 1 /tmp/tx-info.json | head -1 | tr -d '\n'`

cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat payment.addr)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --out-file tx.raw \
            --certificate-file pool-registration.cert \
            --certificate-file delegation.cert

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file payment.skey \
            --signing-key-file stake.skey \
            --signing-key-file cold.skey \
            --testnet-magic 42 \
            --out-file tx.signed

cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode

# Obtain the pool id
POOL_ID=`cardano-cli shelley stake-pool id --verification-key-file cold.vkey`
# Verify that the registration was succesful
echo $POOL_ID
cardano-cli shelley query stake-distribution  --shelley-mode --testnet-magic 42
