#!/usr/bin/env bash
# shellcheck disable=2086

genesisjq()
{
        local q=$1; shift
        jq "$q" ./keys/genesis-meta.json "$@"
}

genesis_check_age() {
        # test $# = 3 || failusage "check-genesis-age HOST SLOTLEN K"
        local startTime=$1 slotlen="${2:-20}" k="${3:-2160}" now
        now=$(date +%s)
        local age_t=$((now - startTime))
        local age_slots=$((age_t / slotlen))
        local remaining=$((k * 2 - age_slots))
        cat <<EOF
---| Genesis:  .startTime=${startTime}  now=${now}  age=${age_t}s  slotlen=${slotlen}
---|           slot age=${age_slots}  k=${k}  remaining=${remaining}
EOF
        if   test "${age_slots}" -ge $((k * 2))
        then fprint "genesis is too old"
             return 1
        elif test "${age_slots}" -ge $((k * 38 / 20))
        then fprint "genesis is dangerously old, slots remaining: ${remaining}"
             return 1
        fi
}

profile_genesis() {
        profile_genesis_$(get_era) "$@"
}

profile_byron_genesis_protocol_params() {
        local prof=$1
        jq --argjson prof "$(profgenjq "${prof}" .)" '
          include "profile-genesis" { search: "bench" };

          byron_genesis_protocol_params($prof)
        ' --null-input
}

profile_byron_genesis_cli_args() {
        local prof=$1
        jq --argjson prof "$(profgenjq "${prof}" .)" '
          include "profile-genesis" { search: "bench" };

          byron_genesis_cli_args($prof)
          | join(" ")
        ' --null-input --raw-output
}

profile_genesis_byron() {
        local prof="${1:-default}"
        local target_dir="${2:-./keys}"
        prof=$(params resolve-profile "$prof")

        local start_future_offset='1 minute' start_time
        start_time="$(date +%s -d "now + ${start_future_offset}")"

        local byron_params_tmpfile
        byron_params_tmpfile=$(mktemp --tmpdir)
        profile_byron_genesis_protocol_params "$prof" >"$byron_params_tmpfile"

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"

        genesis_cli_args=(
        --genesis-output-dir         "$target_dir"
        --start-time                 "$start_time"
        --protocol-parameters-file   "$byron_params_tmpfile"
        $(profile_byron_genesis_cli_args "$prof"))

        cardano-cli genesis --real-pbft "${genesis_cli_args[@]}"
        rm -f "$byron_params_tmpfile"

        cardano-cli print-genesis-hash \
                --genesis-json "$target_dir/genesis.json" |
                tail -1 > "$target_dir"/GENHASH

        profgenjq "$prof" . | jq > "$target_dir"/genesis-meta.json "
          { profile:    \"$prof\"
          , hash:       \"$(cat "$target_dir"/GENHASH)\"
          , start_time: $start_time
          , params: ($(profgenjq "$prof" .))
          }"

        oprint "generated genesis for $prof in:  $target_dir"
}

profile_shelley_genesis_protocol_params() {
        local prof=$1
        jq --argjson prof "$(profgenjq "${prof}" .)" '
          include "profile-genesis" { search: "bench" };

          . * shelley_genesis_protocol_params($prof)
        '
}

profile_shelley_genesis_cli_args() {
        local prof=$1 composition=$2 cmd=$3
        jq --argjson prof        "$(profgenjq "${prof}" .)" \
           --argjson composition "$composition" \
           --arg     cmd         "$cmd" '
          include "profile-genesis" { search: "bench" };

          shelley_genesis_cli_args($prof; $composition; $cmd)
          | join(" ")
        ' --null-input --raw-output
}

profile_genesis_shelley() {
        local prof="${1:-default}"
        local target_dir="${2:-./keys}"
        prof=$(params resolve-profile "$prof")

        local start_future_offset='1 minute'

        local ids_pool_map ids
        ids_pool_map=$(node_count_id_pool_map)
        ids=($(jq 'keys
                  | join(" ")
                  ' -cr <<<$ids_pool_map))
        ids_pool=($(jq ' to_entries
                       | map(select (.value) | .key)
                       | join(" ")
                       ' -cr <<<$ids_pool_map))

        local composition
        composition=$(id_pool_map_composition "$ids_pool_map")

        local magic total_balance pools_balance
        magic=$(profgenjq "$prof" .protocol_magic)
        total_balance=$(profgenjq "$prof" .total_balance)
        pools_balance=$(profgenjq "$prof" .pools_balance)

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"

        params=(--genesis-dir      "$target_dir"
                --gen-utxo-keys    1
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create0'))
        cardano-cli shelley genesis create "${params[@]}"

        ## set parameters in template
        profile_shelley_genesis_protocol_params "$prof" \
         < "$target_dir"/genesis.spec.json > "$target_dir"/genesis.spec.json.
        mv "$target_dir"/genesis.spec.json.  "$target_dir"/genesis.spec.json

        params=(--genesis-dir      "$target_dir"
                --start-time       "$(date --iso-8601=s --date="now + ${start_future_offset}" --utc | cut -c-19)Z"
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create1'))
        ## update genesis from template
        cardano-cli shelley genesis create "${params[@]}"

        for id in ${ids[*]}
        do
            mkdir -p "$target_dir"/node${id}/cold

            cardano-cli shelley node key-gen-KES \
              --verification-key-file "$target_dir"/node${id}/kes.vkey \
              --signing-key-file "$target_dir"/node${id}/kes.skey

            #### cold keys (do not copy to production system)
            if jqtest ".[\"$id\"]" <<<$ids_pool_map; then   ## Stakepool node
                cardano-cli shelley node key-gen \
                --cold-verification-key-file "$target_dir"/node${id}/cold/operator.vkey \
                --cold-signing-key-file "$target_dir"/node${id}/cold/operator.skey \
                --operational-certificate-issue-counter-file "$target_dir"/node${id}/cold/operator.counter
                cardano-cli shelley node key-gen-VRF \
                --verification-key-file "$target_dir"/node${id}/vrf.vkey \
                --signing-key-file "$target_dir"/node${id}/vrf.skey
            else ## BFT node
                local deleg=1
                ln -s ../../delegate-keys/delegate${deleg}.skey    "$target_dir"/node${id}/cold/operator.skey
                ln -s ../../delegate-keys/delegate${deleg}.vkey    "$target_dir"/node${id}/cold/operator.vkey
                ln -s ../../delegate-keys/delegate${deleg}.counter "$target_dir"/node${id}/cold/operator.counter
                ln -s ../delegate-keys/delegate${deleg}.vrf.skey   "$target_dir"/node${id}/vrf.skey
                ln -s ../delegate-keys/delegate${deleg}.vrf.vkey   "$target_dir"/node${id}/vrf.vkey
            fi

            # certificate (adapt kes-period for later certs)
            cardano-cli shelley node issue-op-cert \
              --hot-kes-verification-key-file         "$target_dir"/node${id}/kes.vkey \
              --cold-signing-key-file                 "$target_dir"/node${id}/cold/operator.skey \
              --operational-certificate-issue-counter "$target_dir"/node${id}/cold/operator.counter \
              --kes-period 0 \
              --out-file "$target_dir"/node${id}/node.cert
        done

        # === delegation ===

        ## prepare addresses & set up genesis staking
        mkdir -p "$target_dir"/addresses

        pools_json='{}'
        stake_json='{}'
        initial_funds_json='{}'
        for id in ${ids_pool[*]}
        do
           ### Payment address keys
           cardano-cli shelley address key-gen \
                --verification-key-file         "$target_dir"/addresses/pool-owner${id}.vkey \
                --signing-key-file              "$target_dir"/addresses/pool-owner${id}.skey

           ### Stake address keys
           cardano-cli shelley stake-address key-gen \
                --verification-key-file         "$target_dir"/addresses/pool-owner${id}-stake.vkey \
                --signing-key-file              "$target_dir"/addresses/pool-owner${id}-stake.skey

           ### Payment addresses
           cardano-cli shelley address build \
                --payment-verification-key-file "$target_dir"/addresses/pool-owner${id}.vkey \
                --stake-verification-key-file   "$target_dir"/addresses/pool-owner${id}-stake.vkey \
                --testnet-magic "$magic" \
                --out-file "$target_dir"/addresses/pool-owner${id}.addr

            pool_id=$(cardano-cli shelley stake-pool id \
                      --verification-key-file   "$target_dir"/node${id}/cold/operator.vkey)
            pool_vrf=$(cardano-cli shelley node key-hash-VRF \
                       --verification-key-file  "$target_dir"/node${id}/vrf.vkey)
            deleg_staking=$(cardano-cli shelley stake-address key-hash \
                            --stake-verification-key-file "$target_dir"/addresses/pool-owner${id}-stake.vkey)
            initial_addr=$(cardano-cli shelley address info --address $(cat "$target_dir"/addresses/pool-owner${id}.addr) |
                           jq '.base16' --raw-output)
            params=(
            --arg      poolId          "$pool_id"
            --arg      vrf             "$pool_vrf"
            --arg      delegStaking    "$deleg_staking"
            --arg      initialAddr     "$initial_addr"
            $(profile_shelley_genesis_cli_args "$prof" "$composition" 'pools'))
            pools_json=$(jq '
              . +
              { "\($poolId)":
                { publicKey:     $poolId
                , vrf:           $vrf
                , rewardAccount:
                  { network:     "Testnet"
                  , credential:
                    { "key hash": $delegStaking
                    }
                  }
                , owners:        []
                , relays:        []
                , pledge:        0
                , cost:          0
                , margin:        0
                , metadata: null
                }
              }
              ' <<<$pools_json "${params[@]}" )
            stake_json=$(jq '
              . +
              { "\($delegStaking)": $poolId
              }
              ' <<<$stake_json "${params[@]}" )
            stake_json=$(jq '
              . +
              { "\($delegStaking)": $poolId
              }
              ' <<<$stake_json "${params[@]}" )
            initial_funds_json=$(jq '
              . +
              { "\($initialAddr)": $initialPoolCoin
              }
              ' <<<$initial_funds_json "${params[@]}" )
        done

        sed -i 's_Genesis UTxO verification key_PaymentVerificationKeyShelley_' \
            "$target_dir"/utxo-keys/utxo1.vkey
        sed -i 's_Genesis UTxO signing key_PaymentSigningKeyShelley_' \
            "$target_dir"/utxo-keys/utxo1.skey
        initial_addr_non_pool_bech32=$(cardano-cli shelley address build \
                                       --payment-verification-key-file "$target_dir"/utxo-keys/utxo1.vkey \
                                       --testnet-magic "$magic")
        initial_addr_non_pool_base16=$(cardano-cli shelley address info --address "$initial_addr_non_pool_bech32" |
                                       jq '.base16' --raw-output)

        params=(--argjson pools                   "$pools_json"
                --argjson stake                   "$stake_json"
                --argjson initialFundsOfPools     "$initial_funds_json"
                --arg     initialFundsNonPoolAddr "$initial_addr_non_pool_base16"
                --argjson initialFundsNonPoolCoin $((total_balance - pools_balance))
               )
        jq '. +
           { staking:
             { pools: $pools
             , stake: $stake
             }
           , initialFunds:
             ({ "\($initialFundsNonPoolAddr)":
                   $initialFundsNonPoolCoin
              } + $initialFundsOfPools)
           }
           ' "${params[@]}" \
         < "$target_dir"/genesis.json > "$target_dir"/genesis.json.
        mv "$target_dir"/genesis.json.  "$target_dir"/genesis.json

        ## Fix up the key, so the generator can read it:
        sed -i 's_PaymentSigningKeyShelley_SigningKeyShelley_' "$target_dir"/utxo-keys/utxo1.skey
}
