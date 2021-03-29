# Procedure
#
#   submit_transaction \
#     initial_addr \
#     change_addr \
#     tx_building_cmd \
#     tx_building_args \
#     signing_args \
#     tx_submission_mode
#
# submits a transaction where:
#
# - initial_addr is the address where the funds are going to be taken from.
#   This functions assumes a fee of 0.
#
# - change_addr is the address where the change of the transaction is sent.
#
# - tx_building_cmd is the command to be used to build the transaction.
#   Examples of such commands include: build-raw and pivo-build-raw
#
# - tx_building_args are the arguments to be used when buildng the transaction.
#   Examples of such arguments include update payload file, or certificate
#   files.
#
# - signing_args are the arguments to be passed to the transaction sign
#   command. This argument can be used to pass the signing keys of the
#   transaction.
#
# - tx_submission_mode is the mode used when submitting the transaction.
#   Examples of the available modes are --pivo-mode or --shelley-mode. Remember
#   to include the '--' symbols when specifying a mode!
#
# This script assumes that the $CLI environment variable is set to the command
# used to communicate with the cardano node. This would typically be
submit_transaction() {
    initial_addr=$1
    change_addr=$2
    tx_building_cmd=$3
    tx_building_args=$4
    signing_args=$5
    tx_submission_mode=$6

    ## Submit the signed transaction
    echo "⏳ Submit the signed transaction"
    RETRIES=0
    EXIT_CODE=1
    while [[ $EXIT_CODE -ne 0 ]] && [[ $RETRIES -le 3 ]]; do
        ! try_submit_transaction \
            "$initial_addr" \
            "$change_addr" \
            "$tx_building_cmd" \
            "$tx_building_args" \
            "$signing_args" \
            "$tx_submission_mode"

        EXIT_CODE=${PIPESTATUS[0]}
        echo "⚡ Command exited with code $EXIT_CODE"
        RETRIES=$((RETRIES + 1))
        [ $EXIT_CODE -eq 0 ] || sleep 5;
    done
    [ $EXIT_CODE -eq 0 ] || { echo "Transaction could not be submitted "; return 1; }
    echo "✅ Transaction submitted"
}

try_submit_transaction(){
    initial_addr=$1
    change_addr=$2
    tx_building_cmd=$3
    tx_building_args=$4
    signing_args=$5
    tx_submission_mode=$6

    TX_INFO=/tmp/tx-info.json

    $CLI -- query utxo --testnet-magic 42 --shelley-mode \
         --address $(cat $initial_addr) \
         --out-file $TX_INFO
    INFO=`cat $TX_INFO`
    $CLI -- query utxo --testnet-magic 42 --shelley-mode \
         --address $(cat $initial_addr) \
         --out-file $TX_INFO
    [ "$INFO" != "{}" ] || { echo "Could not get transaction information. Returning"; return 1; }

    BALANCE=`jq '.[].value' $TX_INFO | xargs printf '%.0f\n'`
    TX_IN=`grep -oP '"\K[^"]+' -m 1 $TX_INFO | head -1 | tr -d '\n'`
    # This script assumes the fee to be 0. We might want to check the protocol
    # parameters to make sure that this is indeed the case.
    FEE=0
    CHANGE=`expr $BALANCE - $FEE`
    rm $TX_INFO

    TX_FILE=tx.raw
    # We use a large time-to-live to keep the script simple.
    TTL=1000000
    $CLI -- transaction $tx_building_cmd \
          --tx-in $TX_IN \
          --tx-out $(cat $change_addr)+$CHANGE \
          --invalid-hereafter $TTL \
          --fee $FEE \
          $tx_building_args \
          --out-file $TX_FILE

    SIGNED_TX_FILE=tx.signed
    ## Sign the transaction
    $CLI -- transaction sign \
          --tx-body-file $TX_FILE \
          $signing_args \
          --testnet-magic 42 \
          --out-file $SIGNED_TX_FILE

    ## Submit the signed transaction
    $CLI -- transaction submit \
             --tx-file $SIGNED_TX_FILE \
             --testnet-magic 42 \
             $tx_submission_mode
}

submit_update_transaction() {
    initial_addr=$1
    update_file=$2
    signing_args=$3

    submit_transaction \
        $initial_addr \
        $initial_addr \
        pivo-build-raw \
        "--update-payload-file $update_file" \
        "$signing_args" \
        --pivo-mode
}


# This procedure assumes the $CLI variable is set. See 'submit_transaction'.
register_stakepool(){
    # Path where the stake keys should be created
    stake_key=$1
    # Path where the payment address should be stored. The change will be sent
    # back to this address.
    payment_addr=$2
    # Utxo key used to:
    #
    # - pay for the transaction fees
    # - create a payment address together with the stake key.
    utxo_key=$3
    # Address used to pay for the transaction fees.
    utxo_addr=$4
    # File containing the pool metadata
    metadata_file=$5
    #
    vrf_key=$6
    #
    cold_key=$7

    ##
    ## Stake address registration
    ##
    # Create the stake key files
    $CLI -- stake-address key-gen \
          --verification-key-file $stake_key.vkey \
          --signing-key-file $stake_key.skey

    # Use these keys to create a payment address. This key should have funds
    # associated to it if we want the stakepool to have stake delegated to it.
    $CLI -- address build \
          --payment-verification-key-file $utxo_key.vkey \
          --stake-verification-key-file $stake_key.vkey \
          --out-file $payment_addr \
          --testnet-magic 42

    # Create an address registration certificate, which will be submitted to
    # the blockchain.
    $CLI -- stake-address registration-certificate \
          --stake-verification-key-file $stake_key.vkey \
          --out-file $stake_key.cert

    echo "📜 Submitting the stake registration certificate"
    submit_transaction \
        $utxo_addr \
        $utxo_addr \
        build-raw \
        "--certificate-file $stake_key.cert" \
        "--signing-key-file $utxo_key.skey --signing-key-file $stake_key.skey" \
        --shelley-mode || exit 1

    ##
    ## Stake pool registration
    ##
    # Get the hash of the file:
    METADATA_HASH=`$CLI -- stake-pool metadata-hash --pool-metadata-file $metadata_file`

    # Create a pool registration certificate
    # Pledge amount in Lovelace
    PLEDGE=1000000
    # Pool cost per-epoch in Lovelace
    COST=1000
    # Pool cost per epoch in percentage
    MARGIN=0.1
    POOL_REGISTRATION_CERT=pool-registration.cert
    # Create the registration certificate
    $CLI -- stake-pool registration-certificate \
            --cold-verification-key-file $cold_key.vkey \
            --vrf-verification-key-file $vrf_key.vkey \
            --pool-pledge $PLEDGE \
            --pool-cost $COST \
            --pool-margin $MARGIN \
            --pool-reward-account-verification-key-file $stake_key.vkey \
            --pool-owner-stake-verification-key-file $stake_key.vkey \
            --testnet-magic 42 \
            --metadata-url file://$metadata_file \
            --metadata-hash $METADATA_HASH \
            --out-file $POOL_REGISTRATION_CERT

    # Create a delegation certificate between the stake key and the cold key
    DELEGATION_CERT=delegation.cert
    $CLI -- stake-address delegation-certificate \
            --stake-verification-key-file $stake_key.vkey \
            --cold-verification-key-file $cold_key.vkey \
            --out-file $DELEGATION_CERT

    # Finally submit the transaction
    echo "Waiting to register the stakepool"
    submit_transaction \
        $utxo_addr \
        $payment_addr \
        build-raw \
        "--certificate-file $POOL_REGISTRATION_CERT --certificate-file $DELEGATION_CERT" \
        "--signing-key-file $utxo_key.skey --signing-key-file $stake_key.skey --signing-key-file $COLD.skey " \
        --shelley-mode || exit 1
}
