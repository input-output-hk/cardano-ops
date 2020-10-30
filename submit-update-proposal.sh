
# TODO: get the epoch length from the genesis file.
EPOCH_LENGTH=1000
PROPOSAL_FILE=update.proposal
# This is not very robuts since the epoch might change while we calculate the
# current epoch. We might want to add some logic to ensure that we have enough
# time to submit the proposal before the epoch changes.
SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
PROPOSAL_EPOCH=`expr $SLOT_NO / $EPOCH_LENGTH + 1`

cardano-cli shelley governance create-update-proposal \
            --epoch $PROPOSAL_EPOCH \
            --decentralization-parameter 0.52 \
            --out-file $PROPOSAL_FILE \
            $(for f in keys/genesis-keys/*vkey; do echo "--genesis-verification-key-file $f "; done)

# Get the initial address, which will be used as input by the transaction that
# submits the update proposal.
cardano-cli shelley genesis initial-addr \
            --testnet-magic 42 \
            --verification-key-file keys/utxo-keys/utxo1.vkey > initial.addr

# Build a transaction that contains the update proposal
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat initial.addr) \
            --out-file /tmp/tx-info.json
TX_IN=`grep -oP '"\K[^"]+' -m 1 /tmp/tx-info.json | head -1 | tr -d '\n'`

POOL_DEPOSIT=0
FEE=0
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat initial.addr) \
            --out-file /tmp/balance.json
BALANCE=`jq '.[].amount' /tmp/balance.json | xargs printf '%.0f\n'`
CHANGE=`expr $BALANCE - $POOL_DEPOSIT - $FEE`
TTL=1000000

cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat initial.addr)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --update-proposal-file $PROPOSAL_FILE \
            --out-file tx.raw

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file keys/utxo-keys/utxo1.skey \
            --signing-key-file keys/delegate-keys/delegate1.skey \
            --testnet-magic 42 \
            --out-file tx.signed

#            $(for f in keys/genesis-keys/*skey; do echo "--signing-key-file $f "; done) \

cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode

cardano-cli shelley query ledger-state --testnet-magic 42 --shelley-mode  | jq '.esPrevPp.decentralisationParam'
