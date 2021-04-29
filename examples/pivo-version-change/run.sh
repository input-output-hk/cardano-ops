#!/usr/bin/env bash

set -euo pipefail

. lib.sh

CLI=cardano-cli

################################################################################
## Location of the keys
################################################################################
UTXO=keys/utxo
COLD=keys/cold
VRF=keys/node-vrf

################################################################################
## Named assigned to the other keys created by this script
################################################################################
PROPOSING_KEY=proposing_key
VOTING_KEY=proposing_key # For simplicity the proposing key is also a voting key
PAYMENT_ADDR=payment.addr # Stake address used to tranfer the change of
                          # transactions

################################################################################
## Supported commands
################################################################################
do_stake_pool_registration(){
    # TODO: we obtain the ticker name base on the hostname. We require a
    # certain name format, which depends on the nix setup. We should find a
    # more robust way to do this.
    tickr=`hostname | sed 's/stk-.-\(.\)-IOHK\(.\)/\1\2/'`
    # Create the pool's metadata file
    echo "{
      \"name\": \"PriviPool ${tickr}\",
      \"description\": \"Priviledge Pool ${tickr}\",
      \"ticker\": \"PP${tickr}\",
      \"homepage\": \"https://ppp${tickr}\"
    }" > "pool_metadata.json"

    # TODO: consider removig the pool metadata file.
    # Location of the initial address file used to get the funds from.
    INITIAL_ADDR=initial.addr
    $CLI -- genesis initial-addr \
          --testnet-magic 42 \
          --verification-key-file $UTXO.vkey > $INITIAL_ADDR

    register_stakepool \
      $PROPOSING_KEY \
      $PAYMENT_ADDR \
      $UTXO \
      $INITIAL_ADDR \
      pool_metadata.json \
      $VRF \
      $COLD
}

do_sip_commit(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo sip new \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    # Note that PROPOSING_KEY has to be associated with PAYMENT_ADDR
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $PROPOSING_KEY.skey"
    rm $UPDATE_FILE
}

do_sip_reveal(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo sip reveal \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey" # Note that we do not need to sign with the
                                         # staking key
    rm $UPDATE_FILE
}

do_sip_vote(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo sip vote \
         --stake-verification-key-file $VOTING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $VOTING_KEY.skey"
    rm $UPDATE_FILE
}

do_imp_commit(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo imp commit \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --implementation-version 77 \
         --new-bb-size 131072 \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $PROPOSING_KEY.skey"
    rm $UPDATE_FILE
}

do_imp_reveal(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo imp reveal \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --implementation-version 77 \
         --new-bb-size 131072 \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $PROPOSING_KEY.skey"
    rm $UPDATE_FILE
}

do_imp_vote(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo imp vote \
         --stake-verification-key-file $VOTING_KEY.vkey \
         --proposal-text "hello world!" \
         --implementation-version 77 \
         --new-bb-size 131072 \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $VOTING_KEY.skey"
    rm $UPDATE_FILE
}

do_endorsement(){
    UPDATE_FILE=update.payload
    $CLI -- governance pivo endorse \
         --stake-verification-key-file $VOTING_KEY.vkey \
         --implementation-version 77 \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $VOTING_KEY.skey"
    rm $UPDATE_FILE
}

##
## Commands used in the benchmarking script
##

# Create spending and stake keys.
create_keys(){
    local nr_keys=$1

    mkdir -p stake-keys

    for i in $(seq 1 $nr_keys); do
        # Create a spending key
        $CLI -- address key-gen \
             --verification-key-file keys/spending-key$i.vkey \
             --signing-key-file keys/spending-key$i.skey

        # Create a stake key
        $CLI -- stake-address key-gen \
             --verification-key-file keys/stake-key$i.vkey \
             --signing-key-file keys/stake-key$i.skey
    done

}

transfer_funds(){
    # For simplicity we use a fix amount of Lovelace to transfer to the keys in
    # the 'keys' directory. We assume $PAYMENT_ADDR has enough fnds to cover
    # these transactions.
    local amount=2500000

    # We transfer funds per each spending key
    local nr_keys=$(ls -l keys/spending-key*.vkey | wc -l)

    for i in $(seq 1 $nr_keys); do
        # TODO: can we do this in parallel?
        $CLI --  address build \
             --payment-verification-key-file keys/spending-key$i.vkey \
             --stake-verification-key-file keys/stake-key$i.vkey \
             --out-file keys/payment$i.addr \
             --testnet-magic 42
    done

    # TODO: including a large amount of transaction outputs in a transaction
    # seems to hang something in the client or the node.
    #
    # so it seems we might need to divide this in batches 😩

    # We will use only one transaction to send funds from 'PAYMENT_ADDR' to
    # multiple addresses. We need to build the tx-out arguments.
    txouts=""
    for i in $(seq 1 $nr_keys); do
        txouts=$txouts"--tx-out $(cat keys/payment$i.addr)+$amount "
    done

    local total=$(($amount*$nr_keys))
    submit_transaction \
        $PAYMENT_ADDR \
        $PAYMENT_ADDR \
        build-raw \
        "$txouts" \
        "--signing-key-file $UTXO.skey" \
        --shelley-mode \
        $total
}

do_stake_key_registration(){
    register_stake_key \
        keys/stake-key0 \
        $PAYMENT_ADDR \
        keys/spending-key0 \
        $PAYMENT_ADDR

    # TODO: explain why do we need to delegate the stake
    DELEGATION_CERT=delegation.cert
    $CLI -- stake-address delegation-certificate \
            --stake-verification-key-file keys/stake-key0.vkey \
            --cold-verification-key-file $COLD.vkey \
            --out-file $DELEGATION_CERT

    # TODO: we need to get this right still
    #
    # The key we are delegating to needs to be registered as a stake pool.
    submit_transaction \
        $PAYMENT_ADDR \
        $PAYMENT_ADDR \
        build-raw \
        "--certificate-file $DELEGATION_CERT" \
        "--signing-key-file keys/spending-key0.skey --signing-key-file keys/stake-key0.skey" \
        --shelley-mode || exit 1
}

################################################################################
## Script
################################################################################

# Dispatch the command according to what was specified in the command line
if [ -z ${1+x} ];
then
    echo "Error: no command was specified.";
    exit 1
else
    case $1 in
        register )
            echo "Registering a stakepool"
            do_stake_pool_registration
            exit
            ;;
        scommit )
            echo "Submitting the SIP commit"
            do_sip_commit
            exit
            ;;
        sreveal )
            echo "Revealing the SIP commit"
            do_sip_reveal
            exit
            ;;
        svote )
            echo "Voting for the SIP"
            do_sip_vote
            exit
            ;;
        icommit )
            echo "Submitting the implementation commit"
            do_imp_commit
            exit
            ;;
        ireveal )
            echo "Revealing the implementation commit"
            do_imp_reveal
            exit
            ;;
        ivote )
            echo "Voting for the implementation"
            do_imp_vote
            exit
            ;;
        endorse )
            echo "Endorsing the implementation"
            do_endorsement
            exit
            ;;
        ustquery )
            # TODO: we do not check that arguments have been provided.
            query_update_state $2
            exit
            ;;
        ckeys )
            create_keys $2
            exit
            ;;
        tfunds )
            transfer_funds
            exit
            ;;
        regkey )
            do_stake_key_registration
            exit
            ;;
        * )
            echo "Unknown command $1"
            exit 1
    esac
fi
