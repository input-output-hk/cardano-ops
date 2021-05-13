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
    local tickr=`hostname | sed 's/stk-.-\(.\)-IOHK\(.\)/\1\2/'`
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
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
    $CLI -- governance pivo sip new \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    # Note that PROPOSING_KEY has to be associated with PAYMENT_ADDR
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $PROPOSING_KEY.skey"
    rm -fr $tmp_dir
}

do_sip_reveal(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
    $CLI -- governance pivo sip reveal \
         --stake-verification-key-file $PROPOSING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey" # Note that we do not need to sign with the
                                         # staking key
    rm -fr $tmp_dir
}

do_sip_vote(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
    $CLI -- governance pivo sip vote \
         --stake-verification-key-file $VOTING_KEY.vkey \
         --proposal-text "hello world!" \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $VOTING_KEY.skey"
    rm -fr $tmp_dir
}

do_imp_commit(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
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
    rm -fr $tmp_dir
}

do_imp_reveal(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
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
    rm -fr $tmp_dir
}

do_imp_vote(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
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
    rm -fr $tmp_dir
}

do_endorsement(){
    local tmp_dir=$(mktemp -d)
    local UPDATE_FILE=$tmp_dir/update.payload
    $CLI -- governance pivo endorse \
         --stake-verification-key-file $VOTING_KEY.vkey \
         --implementation-version 77 \
         --out-file $UPDATE_FILE
    submit_update_transaction \
        $PAYMENT_ADDR \
        $UPDATE_FILE \
        "--signing-key-file $UTXO.skey --signing-key-file $VOTING_KEY.skey"
    rm -fr $tmp_dir
}

##
## Commands used in the benchmarking script
##

# Create spending and stake keys.
create_keys(){
    local nr_keys=$1

    # TODO: confirm that this is actually 'keys'
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
        $CLI -- address build \
             --payment-verification-key-file keys/spending-key$i.vkey \
             --stake-verification-key-file keys/stake-key$i.vkey \
             --out-file keys/payment$i.addr \
             --testnet-magic 42
    done

    # There is a limit in the number of output addresses we can fit in a given
    # transaction, since we are limited by the transaction size and by the
    # block size. Therefore we submit the transactions in batches.
    local batch_size=200
    local batch=1
    local i=1
    while [[ $i -le $nr_keys ]]; do
        local n=0
        local txouts=""
        while [[ $i -le $(($batch_size * $batch)) ]] && [[ $i -le $nr_keys ]]; do
            # We will use only one transaction to send funds from 'PAYMENT_ADDR' to
            # multiple addresses. We need to build the tx-out arguments.
            txouts=$txouts"--tx-out $(cat keys/payment$i.addr)+$amount "
            n=$((n + 1))
            i=$((i + 1))
        done
        local total=$(($amount*$n))
        submit_transaction \
            $PAYMENT_ADDR \
            $PAYMENT_ADDR \
            build-raw \
            "$txouts" \
            "--signing-key-file $UTXO.skey" \
            --shelley-mode \
            $total
        batch=$((batch + 1))
    done
}

do_stake_key_registration(){
    local nr_keys=$(ls -l keys/spending-key*.vkey | wc -l)
    for i in $(seq 1 $nr_keys); do
        register_key $i &
    done
    wait
}

register_key(){
    echo "********************************************************************************"
    echo "Registering and delegating key $1"
    echo "********************************************************************************"

    local key_addr=keys/payment$1.addr

    echo "Registering the stake key"
    register_stake_key \
        keys/stake-key$1 \
        $key_addr \
        keys/spending-key$1 \
        $key_addr

    echo "Delegating the stake key"
    # We need to delegate our stake because only active stake is added to
    # the stake distribution snapshot.
    local DELEGATION_CERT=delegation$1.cert
    $CLI -- stake-address delegation-certificate \
         --stake-verification-key-file keys/stake-key$1.vkey \
         --cold-verification-key-file $COLD.vkey \
         --out-file $DELEGATION_CERT

    # The key we are delegating to needs to be registered as a stake pool.
    submit_transaction \
        $key_addr \
        $key_addr \
        build-raw \
        "--certificate-file $DELEGATION_CERT" \
        "--signing-key-file keys/spending-key$1.skey --signing-key-file keys/stake-key$1.skey" \
        --shelley-mode || exit 1
}

# Vote on an SIP with the stake keys.
do_sip_skeys_vote(){
    local nr_keys=$(ls -l keys/spending-key*.vkey | wc -l)
    for i in $(seq 1 $nr_keys); do
        skey_vote $i &
    done
    wait
}

skey_vote(){
    local tmp_dir=$(mktemp -d)
    local update_file=$tmp_dir/update.payload
    local key_addr=keys/payment$1.addr
    local voting_key=keys/stake-key$1
    $CLI -- governance pivo sip vote \
         --stake-verification-key-file $voting_key.vkey \
         --proposal-text "hello world!" \
         --out-file $update_file
    submit_update_transaction \
        $key_addr \
        $update_file \
        "--signing-key-file keys/spending-key$1.skey --signing-key-file $voting_key.skey"
    rm -fr $tmp_dir

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
        qsipballot )
            echo "Number of votes: "
            $CLI query ledger-state --testnet-magic 42 \
                 --pivo-era --pivo-mode \
                | jq ".stateBefore.esLState.utxoState.ppups.ideationSt.proposalsState[0][1].ballot | .[][0][]" \
                | wc -l
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
        sip_skvote )
            do_sip_skeys_vote
            exit
            ;;
        * )
            echo "Unknown command $1"
            exit 1
    esac
fi
