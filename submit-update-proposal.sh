PROPOSAL_FILE=update.proposal
PROPOSAL_EPOCH=0

cardano-cli shelley governance create-update-proposal \
            --epoch $PROPOSAL_EPOCH \
            --decentralization-parameter 0.52 \
            --out-file $PROPOSAL_FILE \
            $(for f in genesis-keys/*vkey; do echo "--genesis-verification-key-file $f "; done)

# Build a transaction that contains the update proposal
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat payment.addr) \
            --out-file /tmp/tx-info.json
TX_IN=`grep -oP '"\K[^"]+' -m 1 /tmp/tx-info.json | head -1 | tr -d '\n'`

FEE=0
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode \
            --address $(cat payment.addr) \
            --out-file /tmp/balance.json
BALANCE=`jq '.[].amount' /tmp/balance.json | xargs printf '%.0f\n'`
CHANGE=`expr $BALANCE - $POOL_DEPOSIT - $FEE`
TTL=1000000

cardano-cli shelley transaction build-raw \
            --tx-in $TX_IN \
            --tx-out $(cat payment.addr)+$CHANGE \
            --ttl $TTL \
            --fee $FEE \
            --update-proposal-file $PROPOSAL_FILE \
            --out-file tx.raw

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            $(for f in genesis-keys/*skey; do echo "--signing-key-file $f "; done) \
            --testnet-magic 42 \
            --out-file tx.signed
