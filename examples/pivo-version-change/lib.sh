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
    local initial_addr=$1
    local change_addr=$2
    local tx_building_cmd=$3
    local tx_building_args=$4
    local signing_args=$5
    local tx_submission_mode=$6
    local transfer_amount=${7:-0}

    ## Submit the signed transaction
    echo "⏳ Submit the signed transaction"
    local RETRIES=0
    local EXIT_CODE=1
    while [[ $EXIT_CODE -ne 0 ]] && [[ $RETRIES -le 30 ]]; do
        ! (try_submit_transaction \
            "$initial_addr" \
            "$change_addr" \
            "$tx_building_cmd" \
            "$tx_building_args" \
            "$signing_args" \
            "$tx_submission_mode" \
            "$transfer_amount")
            # "$transfer_amount" 2> /dev/null)

        EXIT_CODE=${PIPESTATUS[0]}
        # echo "⚡ Command exited with code $EXIT_CODE"
        RETRIES=$((RETRIES + 1))
        [ $EXIT_CODE -eq 0 ] || sleep 5;
    done
    [ $EXIT_CODE -eq 0 ] || { return 1; }
    echo "✅ Transaction submitted"
}

try_submit_transaction(){
    local initial_addr=$1
    local change_addr=$2
    local tx_building_cmd=$3
    local tx_building_args=$4
    local signing_args=$5
    local tx_submission_mode=$6
    local transfer_amount=$7

    local tmp_dir=$(mktemp -d)
    local TX_INFO=$tmp_dir/tx-info.json

    $CLI -- query utxo --testnet-magic 42 --shelley-mode \
         --address $(cat $initial_addr) \
         --out-file $TX_INFO
    local INFO=`cat $TX_INFO`
    $CLI -- query utxo --testnet-magic 42 --shelley-mode \
         --address $(cat $initial_addr) \
         --out-file $TX_INFO
    [ "$INFO" != "{}" ] || { return 1; }

    local BALANCE=`sed -n 's/\s*"value": \([[:digit:]]*\),/\1/p' $TX_INFO`
    local TX_IN=`grep -oP '"\K[^"]+' -m 1 $TX_INFO | head -1 | tr -d '\n'`
    # This script assumes the fee to be 0. We might want to check the protocol
    # parameters to make sure that this is indeed the case.
    local FEE=0
    local CHANGE=`expr $BALANCE - $FEE - $transfer_amount`

    local TX_FILE=$tmp_dir/tx.raw
    # We use a large time-to-live to keep the script simple.
    local TTL=1000000
    $CLI -- transaction $tx_building_cmd \
          --tx-in $TX_IN \
          --tx-out $(cat $change_addr)+$CHANGE \
          --invalid-hereafter $TTL \
          --fee $FEE \
          $tx_building_args \
          --out-file $TX_FILE

    local SIGNED_TX_FILE=$tmp_dir/tx.signed
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
    local tx_sub_exit_code=$?
    rm -fr $tmp_dir
    return $tx_sub_exit_code
}

submit_update_transaction() {
    local initial_addr=$1
    local update_file=$2
    local signing_args=$3

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
    local stake_key=$1
    # Path where the payment address should be stored. The change will be sent
    # back to this address.
    local payment_addr=$2
    # Utxo key used to:
    #
    # - pay for the transaction fees
    # - create a payment address together with the stake key.
    local utxo_key=$3
    # Address used to pay for the transaction fees.
    local utxo_addr=$4
    # File containing the pool metadata
    local metadata_file=$5
    #
    local vrf_key=$6
    #
    local cold_key=$7


    # Create the stake key files
    $CLI -- stake-address key-gen \
          --verification-key-file $stake_key.vkey \
          --signing-key-file $stake_key.skey

    register_stake_key \
        $stake_key \
        $payment_addr \
        $utxo_key \
        $utxo_addr

    ##
    ## Stake pool registration
    ##
    # Get the hash of the file:
    local METADATA_HASH=`$CLI -- stake-pool metadata-hash --pool-metadata-file $metadata_file`

    # Create a pool registration certificate
    # Pledge amount in Lovelace
    local PLEDGE=1000000
    # Pool cost per-epoch in Lovelace
    local COST=1000
    # Pool cost per epoch in percentage
    local MARGIN=0.1
    local POOL_REGISTRATION_CERT=pool-registration.cert
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
    local tmp_dir=$(mktemp -d)
    local DELEGATION_CERT=$tmp_dir/delegation.cert
    $CLI -- stake-address delegation-certificate \
            --stake-verification-key-file $stake_key.vkey \
            --cold-verification-key-file $cold_key.vkey \
            --out-file $DELEGATION_CERT

    # Finally submit the transaction
    echo "Waiting to register the stakepool"
    submit_transaction \
        $payment_addr \
        $payment_addr \
        build-raw \
        "--certificate-file $POOL_REGISTRATION_CERT --certificate-file $DELEGATION_CERT" \
        "--signing-key-file $utxo_key.skey --signing-key-file $stake_key.skey --signing-key-file $cold_key.skey " \
        --shelley-mode || (rm -fr $tmp_dir; exit 1)
    rm -fr $tmp_dir
}

register_stake_key(){
    # Path where the stake keys should be created
    local stake_key=$1
    # Path where the payment address should be stored. The change will be sent
    # back to this address.
    local payment_addr=$2
    # Utxo key used to:
    #
    # - pay for the transaction fees
    # - create a payment address together with the stake key.
    local utxo_key=$3
    # Address used to pay for the transaction fees.
    local utxo_addr=$4

    ##
    ## Stake address registration
    ##

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
        $payment_addr \
        build-raw \
        "--certificate-file $stake_key.cert" \
        "--signing-key-file $utxo_key.skey --signing-key-file $stake_key.skey" \
        --shelley-mode || exit 1

}

pretty_sleep(){
    local duration=$1
    local message=$2

    echo -ne "⏳ $message: "
    tput sc
    while [[ 0 -lt $duration ]]; do
        tput rc
        echo -ne "$duration       \r"
        sleep 1
        duration=$((duration - 1))
    done
    echo
}

query_update_state(){
    local comp=$1
    $CLI query ledger-state --testnet-magic 42 \
     --pivo-era --pivo-mode \
    | jq ".stateBefore.esLState.utxoState.ppups.$comp"
}

try_till_success(){
    local exit_code=1
    while [[ $exit_code -ne 0 ]];
    do
        ! $1
        # ! $1 2> /dev/null
        exit_code=${PIPESTATUS[0]}
        sleep 5
    done
}
