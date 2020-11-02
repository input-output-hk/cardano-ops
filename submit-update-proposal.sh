set -euo pipefail
# TODO: Wait till the network starts
# SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
# while [ ]

# Payment key to pay for the different transactions in this script.
UTXO=keys/utxo
DELEGATE=keys/delegate
FEE=0
TTL=1000000

# TODO: get the epoch length from the genesis file.
EPOCH_LENGTH=1000
PROPOSAL_FILE=update.proposal

# Wait till the beginning of a new epoch and set that epoch as $PROPOSAL_EPOCH
SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
CURRENT_EPOCH=$((SLOT_NO / EPOCH_LENGTH))
PROPOSAL_EPOCH=$((CURRENT_EPOCH + 1))
echo "Current epoch: $CURRENT_EPOCH, proposal epoch: $PROPOSAL_EPOCH"
while [ "$CURRENT_EPOCH" -lt "$PROPOSAL_EPOCH"  ]; do
    sleep 5
    SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
    CURRENT_EPOCH=$((SLOT_NO / EPOCH_LENGTH))
    echo -ne "Current slot: $SLOT_NO, epoch will change on slot $((EPOCH_LENGTH*PROPOSAL_EPOCH))\r"
done
echo

GENESIS=keys/genesis
D_PARAM=0.59
cardano-cli shelley governance create-update-proposal \
            --epoch $PROPOSAL_EPOCH \
            --decentralization-parameter $D_PARAM \
            --out-file $PROPOSAL_FILE \
            --genesis-verification-key-file $GENESIS.vkey


INITIAL_ADDR=initial.addr
# Get the initial address, which will be used as input by the transaction that
# submits the update proposal.
cardano-cli shelley genesis initial-addr \
            --testnet-magic 42 \
            --verification-key-file $UTXO.vkey > $INITIAL_ADDR

TX_INFO=/tmp/tx-info.json
# Build a transaction that contains the update proposal
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat $INITIAL_ADDR) \
            --out-file $TX_INFO
TX_IN=`grep -oP '"\K[^"]+' -m 1 $TX_INFO | head -1 | tr -d '\n'`

cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat initial.addr) \
            --out-file /tmp/balance.json
BALANCE=`jq '.[].amount' /tmp/balance.json | xargs printf '%.0f\n'`
CHANGE=`expr $BALANCE - $FEE`

cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat $INITIAL_ADDR)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --update-proposal-file $PROPOSAL_FILE \
            --out-file tx.raw
cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file $UTXO.skey \
            --signing-key-file $DELEGATE.skey \
            --testnet-magic 42 \
            --out-file tx.signed
cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode

SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
CURRENT_EPOCH=`expr $SLOT_NO / $EPOCH_LENGTH`
ACTIVATION_EPOCH=`expr $PROPOSAL_EPOCH + 1`
echo "Current epoch: $CURRENT_EPOCH, proposal active on epoch $ACTIVATION_EPOCH"
while [ "$CURRENT_EPOCH" -lt "$ACTIVATION_EPOCH"  ]; do
    sleep 1
    SLOT_NO=`cardano-cli shelley query tip --testnet-magic 42 | jq ".slotNo"`
    CURRENT_EPOCH=`expr $SLOT_NO / $EPOCH_LENGTH`
    echo -ne "Current slot: $SLOT_NO, epoch will change on slot $((EPOCH_LENGTH*(CURRENT_EPOCH+1)))\r"
done

echo

CURRENT_D_PARAM=`cardano-cli shelley query ledger-state --testnet-magic 42 --shelley-mode  | jq '.esPrevPp.decentralisationParam'`

if [ "$CURRENT_D_PARAM" = "$D_PARAM" ];
then
    echo "Decentralization parameter successfully changed."
else
    echo "Decentralization parameter was not changed."
    echo "Current decentralization parameter: $CURRENT_D_PARAM"
    echo "Expected decentralization parameter: $D_PARAM "
fi
