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

profile_genesis_hash() {
        profile_genesis_hash_$(get_era) "$@"
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

__KEY_ROOT=
key_depl() {
        local type=$1 kind=$2 id=$3
        case "$kind" in
                bulk )     suffix='.creds';;
                cert )     suffix='.cert';;
                count )    suffix='.counter';;
                none )     suffix='';;
                sig )      suffix='.skey';;
                ver )      suffix='.vkey';;
                * )        fail "key_depl: unknown key kind: '$kind'";; esac
        case "$type" in
                bulk )     stem=node-keys/bulk${id};;
                cold )     stem=node-keys/cold/operator${id};;
                opcert )   stem=node-keys/node${id}.opcert;;
                KES )      stem=node-keys/node-kes${id};;
                VRF )      stem=node-keys/node-vrf${id};;
                * )        fail "key_depl: unknown key type: '$type'";; esac
        echo "$__KEY_ROOT"/${stem}${suffix}
}
key_genesis() {
        local type=$1 kind=$2 id=$3
        case "$kind" in
                bulk )     suffix='.creds';;
                cert )     suffix='.cert';;
                count )    suffix='.counter';;
                none )     suffix='';;
                sig )      suffix='.skey';;
                ver )      suffix='.vkey';;
                * )        fail "key_genesis: unknown key kind: '$kind'";; esac
        case "$type" in
                bulk )     stem=pools/bulk${id};;
                cold )     stem=pools/cold${id};;
                opcert )   stem=pools/opcert${id};;
                KES )      stem=pools/kes${id};;
                VRF )      stem=pools/vrf${id};;
                deleg )    stem=delegate-keys/delegate${id};;
                delegCert )stem=delegate-keys/opcert${id};;
                delegKES ) stem=delegate-keys/delegate${id}.kes;;
                delegVRF ) stem=delegate-keys/delegate${id}.vrf;;
                * )        fail "key_genesis: unknown key type: '$type'";; esac
        echo "$__KEY_ROOT"/${stem}${suffix}
}

keypair_args() {
        local type=$1 id=$2 cliargprefix=${3:-}
        args=(--"${cliargprefix}"verification-key-file "$(key_depl "$type" ver "$id")"
              --"${cliargprefix}"signing-key-file      "$(key_depl "$type" sig "$id")"
             )
        if test "$type" = 'cold'
        then args+=(--operational-certificate-issue-counter-file
                    "$(key_depl cold count "$id")"); fi
        echo ${args[*]}
}

cli() {
        echo "---)  cardano-cli $*" >&2
        cardano-cli "$@" || fail "cli invocation failed"
}

profile_genesis_shelley_incremental() {
        set -o pipefail

        local prof="${1:-default}"
        local target_dir="${2:-./keys}"
        prof=$(params resolve-profile "$prof")

        local start_future_offset='1 minute'
        local ids_pool_map ids
        id_pool_map_composition ""

        local topofile
        topofile=$(get_topology_file)
        oprint "genesis: topology:  $topofile"

        ids_pool_map=$(topology_id_pool_density_map "$topofile")
        oprint "genesis: id-pool map:  $ids_pool_map"
        if jqtest 'to_entries | map (select (.value != 0)) | length == 0' <<<$ids_pool_map
        then fail "no pools in topology -- at least one entry must be have:  pools = <NON-ZERO>"
        fi

        ids=($(jq 'keys
                  | join(" ")
                  ' -cr <<<$ids_pool_map))
        ids_pool=($(jq ' to_entries
                       | map(select (.value != 0) | .key)
                       | join(" ")
                       ' -cr <<<$ids_pool_map))

        local composition
        composition=$(id_pool_map_composition "$ids_pool_map")
        oprint "genesis: id-pool map composition:  $ids_pool_map"

        local magic total_balance pools_balance
        magic=$(profgenjq "$prof" .protocol_magic)
        total_balance=$(profgenjq "$prof" .total_balance)
        pools_balance=$(profgenjq "$prof" .pools_balance)

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"
        __KEY_ROOT="$target_dir"

        params=(--genesis-dir      "$target_dir"
                --gen-utxo-keys    1
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create0'))
        cli shelley genesis create "${params[@]}"

        ## set parameters in template
        profile_shelley_genesis_protocol_params "$prof" \
         < "$target_dir"/genesis.spec.json > "$target_dir"/genesis.spec.json.
        mv "$target_dir"/genesis.spec.json.  "$target_dir"/genesis.spec.json

        params=(--genesis-dir      "$target_dir"
                --start-time       "$(date --iso-8601=s --date="now + ${start_future_offset}" --utc | cut -c-19)Z"
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create1'))
        ## update genesis from template
        cli shelley genesis create "${params[@]}"

        local deleg_id=1
        for id in ${ids[*]}
        do
            mkdir -p "$target_dir"/node-keys/cold

            cli shelley node key-gen-KES $(keypair_args KES $id)

            #### cold keys (do not copy to production system)
            if jqtest ".[\"$id\"]" <<<$ids_pool_map; then   ## Stakepool node
                cli shelley node key-gen \
                  $(keypair_args cold $id 'cold-')
                cli shelley node key-gen-VRF \
                  $(keypair_args VRF  $id)
            else ## BFT node
                cp -a $(key_depl deleg sig    $deleg_id) $(key_depl cold sig   $id)
                cp -a $(key_depl deleg ver    $deleg_id) $(key_depl cold ver   $id)
                cp -a $(key_depl deleg count  $deleg_id) $(key_depl cold count $id)
                cp -a $(key_depl delegVRF sig $deleg_id) $(key_depl VRF  sig   $id)
                cp -a $(key_depl delegVRF ver $deleg_id) $(key_depl VRF  ver   $id)
                deleg_id=$((deleg_id + 1))
            fi

            # certificate (adapt kes-period for later certs)
            cli shelley node issue-op-cert \
              --kes-period 0 \
              --hot-kes-verification-key-file         $(key_depl KES  ver    $id) \
              --cold-signing-key-file                 $(key_depl cold sig    $id) \
              --operational-certificate-issue-counter $(key_depl cold count  $id) \
              --out-file                              $(key_depl opcert none $id)
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
           cli shelley address key-gen \
                --verification-key-file         "$target_dir"/addresses/pool-owner${id}.vkey \
                --signing-key-file              "$target_dir"/addresses/pool-owner${id}.skey

           ### Stake address keys
           cli shelley stake-address key-gen \
                --verification-key-file         "$target_dir"/addresses/pool-owner${id}-stake.vkey \
                --signing-key-file              "$target_dir"/addresses/pool-owner${id}-stake.skey

           ### Payment addresses
           cli shelley address build \
                --payment-verification-key-file "$target_dir"/addresses/pool-owner${id}.vkey \
                --staking-verification-key-file   "$target_dir"/addresses/pool-owner${id}-stake.vkey \
                --testnet-magic "$magic" \
                --out-file "$target_dir"/addresses/pool-owner${id}.addr

            pool_id=$(cli shelley stake-pool id \
                      --verification-key-file   $(key_depl cold ver $id) --output-format hex)
            pool_vrf=$(cli shelley node key-hash-VRF \
                       --verification-key-file  $(key_depl VRF  ver $id))
            deleg_staking=$(cli shelley stake-address key-hash \
                            --staking-verification-key-file "$target_dir"/addresses/pool-owner${id}-stake.vkey)
            initial_addr=$(cli shelley address info --address $(cat "$target_dir"/addresses/pool-owner${id}.addr) |
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
        initial_addr_non_pool_bech32=$(cli shelley address build \
                                       --payment-verification-key-file "$target_dir"/utxo-keys/utxo1.vkey \
                                       --testnet-magic "$magic")
        initial_addr_non_pool_base16=$(cli shelley address info --address "$initial_addr_non_pool_bech32" |
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

profile_genesis_shelley_singleshot() {
        set -euo pipefail

        local prof="${1:-default}"
        local target_dir="${2:-./keys}"
        prof=$(params resolve-profile "$prof")

        local start_future_offset='1 minute'
        local ids_pool_map ids
        id_pool_map_composition ""

        local topofile
        topofile=$(get_topology_file)
        oprint "genesis: topology:  $topofile"

        ids_pool_map=$(topology_id_pool_density_map "$topofile")
        oprint "genesis: id-pool map:  $ids_pool_map"
        if jqtest 'to_entries | map (select (.value)) | length == 0' <<<$ids_pool_map
        then fail "no pools in topology -- at least one entry must be have:  pools = <NON-ZERO>"
        fi

        ids=($(jq 'keys
                  | join(" ")
                  ' -cr <<<$ids_pool_map))

        local composition
        composition=$(id_pool_map_composition "$ids_pool_map")
        oprint "genesis: id-pool map composition:  $composition"

        local magic total_balance pools_balance
        magic=$(profgenjq "$prof" .protocol_magic)
        total_balance=$(profgenjq "$prof" .total_balance)
        pools_balance=$(profgenjq "$prof" .pools_balance)
        # dense_pools_balance=$(profgenjq "$prof" .dense_pools_balance)

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"
        __KEY_ROOT="$target_dir"

        params=(--genesis-dir      "$target_dir"
                --gen-utxo-keys    1
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create0'))
        cli shelley genesis create "${params[@]}"

        ## set parameters in template
        profile_shelley_genesis_protocol_params "$prof" \
         < "$target_dir"/genesis.spec.json > "$target_dir"/genesis.spec.json.
        mv "$target_dir"/genesis.spec.json.  "$target_dir"/genesis.spec.json

        params=(--genesis-dir      "$target_dir"
                --start-time       "$(date --iso-8601=s --date="now + ${start_future_offset}" --utc | cut -c-19)Z"
                $(profile_shelley_genesis_cli_args "$prof" "$composition" 'create1')
               )
        ## update genesis from template
        cli shelley genesis create-staked "${params[@]}"

        genesis_shelley_copy_keys "$ids_pool_map"

        cli shelley genesis hash \
                --genesis "$target_dir/genesis.json" |
                tail -1 > "$target_dir"/GENHASH

        ## Fix up the key, so the generator can read it:
        sed -i 's_PaymentSigningKeyShelley_SigningKeyShelley_' "$target_dir"/utxo-keys/utxo1.skey
}

genesis_shelley_copy_keys() {
        local ids_pool_map=$1
        local ids ids_pool

        set -e

        ids=($(jq 'keys
                  | join(" ")
                  ' -cr <<<$ids_pool_map))
        ids_pool=($(jq ' to_entries
                       | map(select (.value != 0) | .key)
                       | join(" ")
                       ' -cr <<<$ids_pool_map))
        local bid=1 pid=1 did=1 ## (B)FT, (P)ool, (D)ense pool
        for id in ${ids[*]}
        do
            mkdir -p "$target_dir"/node-keys/cold

            #### cold keys (do not copy to production system)
            elif jqtest ".[\"$id\"] == 1" <<<$ids_pool_map
            then ## Singular pool
               oprint "genesis:  pool $pid -> node-$id"
               cp -f $(key_genesis cold       sig $pid) $(key_depl cold    sig $id)
               cp -f $(key_genesis cold       ver $pid) $(key_depl cold    ver $id)
               cp -f $(key_genesis opcert    cert $pid) $(key_depl opcert none $id)
               cp -f $(key_genesis opcert   count $pid) $(key_depl cold  count $id)
               cp -f $(key_genesis KES        sig $pid) $(key_depl KES     sig $id)
               cp -f $(key_genesis KES        ver $pid) $(key_depl KES     ver $id)
               cp -f $(key_genesis VRF        sig $pid) $(key_depl VRF     sig $id)
               cp -f $(key_genesis VRF        ver $pid) $(key_depl VRF     ver $id)
               pid=$((pid + 1))
            else ## BFT node
               oprint "genesis:  BFT $bid -> node-$id"
               cp -f $(key_genesis deleg      sig $bid) $(key_depl cold    sig $id)
               cp -f $(key_genesis deleg      ver $bid) $(key_depl cold    ver $id)
               cp -f $(key_genesis delegCert cert $bid) $(key_depl opcert none $id)
               cp -f $(key_genesis deleg    count $bid) $(key_depl cold  count $id)
               cp -f $(key_genesis delegKES   sig $bid) $(key_depl KES     sig $id)
               cp -f $(key_genesis delegKES   ver $bid) $(key_depl KES     ver $id)
               cp -f $(key_genesis delegVRF   sig $bid) $(key_depl VRF     sig $id)
               cp -f $(key_genesis delegVRF   ver $bid) $(key_depl VRF     ver $id)
               bid=$((bid + 1))
            fi
        done
}

profile_genesis_shelley() {
        profile_genesis_shelley_singleshot "$@"
}

profile_genesis_hash_byron() {
        local genesis_dir="${1:-./keys}"
        cat ${genesis_dir}/GENHASH
}

profile_genesis_hash_shelley() {
        local genesis_dir="${1:-./keys}"

        cardano-cli shelley genesis hash --genesis ${genesis_dir}/genesis.json | tr -d '"'
}
