UTXO=keys/utxo-keys/utxo2
STAKE=stake
PAYMENT_ADDR=payment.addr
COLD=keys/node-keys/cold2
VRF=keys/node-keys/node-vrf2

# This script assumes the fee to be 0. We might want to check the protocol
# parameters to make sure that this is indeed the case.
FEE=0
# We use a large time-to-live to keep the script simple.
TTL=1000000

# Create a new stake key pair
cardano-cli shelley stake-address key-gen \
            --verification-key-file $STAKE.vkey \
            --signing-key-file $STAKE.skey
# Use these keys to create a payment address:
cardano-cli shelley address build \
            --payment-verification-key-file $UTXO.vkey \
            --stake-verification-key-file $STAKE.vkey \
            --out-file $PAYMENT_ADDR \
            --testnet-magic 42

# Register the stake address on the blockchain
cardano-cli shelley stake-address registration-certificate \
            --stake-verification-key-file $STAKE.vkey \
            --out-file $STAKE.cert
INITIAL_ADDR=initial.addr
# Get the initial address from which we will transfer the funds
cardano-cli shelley genesis initial-addr \
            --testnet-magic 42 \
            --verification-key-file $UTXO.vkey > $INITIAL_ADDR
# Check the balance on the initial address so that we can submit different
# transactions.
TX_INFO=/tmp/tx-info.json
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat $INITIAL_ADDR) \
            --out-file $TX_INFO
BALANCE=`jq '.[].amount' $TX_INFO | xargs printf '%.0f\n'`
TX_IN=`grep -oP '"\K[^"]+' -m 1 $TX_INFO | head -1 | tr -d '\n'`
CHANGE=`expr $BALANCE - $FEE`

cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat $INITIAL_ADDR)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --out-file tx.raw \
            --certificate-file $STAKE.cert
cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file $UTXO.skey \
            --signing-key-file $STAKE.skey \
            --testnet-magic 42 \
            --out-file tx.signed
cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode

METADATA_FILE=pool-metadata.json
echo '{
  "name": "PriviPool",
  "description": "Priviledge Pool",
  "ticker": "TEST",
  "homepage": "https://ppp"
}' > $METADATA_FILE
# Get the hash of the file:
METADATA_HASH=`cardano-cli shelley stake-pool metadata-hash --pool-metadata-file pool-metadata.json`

# Pledge amount in Lovelace
PLEDGE=1000000
# Pool cost per-epoch in Lovelace
COST=1000
# Pool cost per epoch in percentage
MARGIN=0.1
POOL_REGISTRATION_CERT=pool-registration.cert
# Create the registration certificate
cardano-cli shelley stake-pool registration-certificate \
            --cold-verification-key-file $COLD.vkey \
            --vrf-verification-key-file $VRF.vkey \
            --pool-pledge $PLEDGE \
            --pool-cost $COST \
            --pool-margin $MARGIN \
            --pool-reward-account-verification-key-file $STAKE.vkey \
            --pool-owner-stake-verification-key-file $STAKE.vkey \
            --testnet-magic 42 \
            --metadata-url file://$METADATA_FILE \
            --metadata-hash $METADATA_HASH \
            --out-file $POOL_REGISTRATION_CERT

# Generate a delegation certificate pledge
DELEGATION_CERT=delegation.cert
cardano-cli shelley stake-address delegation-certificate \
            --stake-verification-key-file $STAKE.vkey \
            --cold-verification-key-file $COLD.vkey \
            --out-file $DELEGATION_CERT

# Registering a stake pool requires a deposit, which is specified in the
# genesis file. Here we assume the deposit is 0.
POOL_DEPOSIT=0
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat $INITIAL_ADDR) \
            --out-file $TX_INFO
BALANCE=`jq '.[].amount' $TX_INFO | xargs printf '%.0f\n'`
TX_IN=`grep -oP '"\K[^"]+' -m 1 $TX_INFO | head -1 | tr -d '\n'`
CHANGE=`expr $BALANCE - $POOL_DEPOSIT - $FEE`

# Create, sign, and submit the transaction
cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat $INITIAL_ADDR)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --out-file tx.raw \
            --certificate-file $POOL_REGISTRATION_CERT \
            --certificate-file $DELEGATION_CERT
cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file $UTXO.skey \
            --signing-key-file $STAKE.skey \
            --signing-key-file $COLD.skey \
            --testnet-magic 42 \
            --out-file tx.signed
cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode
