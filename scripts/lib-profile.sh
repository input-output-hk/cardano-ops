#!/usr/bin/env bash
# shellcheck disable=2086

## Profile Cluster
pjq() {
        rcjq "del(.meta)
             | if has(\"$1\") then .[\"$1\"] $2
               else error(\"Can't query unknown profile $1 using $2\") end"
}

profile_byron_protocol_params() {
        local prof=$1
        jq <<<'{
    "heavyDelThd": "300000000000",
    "maxBlockSize": "'"$(pjq "${prof}" .genesis_params.max_block_size)"'",
    "maxHeaderSize": "2000000",
    "maxProposalSize": "700",
    "maxTxSize": "4096",
    "mpcThd": "20000000000000",
    "scriptVersion": 0,
    "slotDuration": "'"$(pjq "${prof}" .genesis_params.slot_duration)"'",
    "softforkRule": {
        "initThd": "900000000000000",
        "minThd": "600000000000000",
        "thdDecrement": "50000000000000"
    },
    "txFeePolicy": {
        "multiplier": "43946000000",
        "summand": "155381000000000"
    },
    "unlockStakeEpoch": "18446744073709551615",
    "updateImplicit": "10000",
    "updateProposalThd": "100000000000000",
    "updateVoteThd": "1000000000000"
}'
}

profile_genesis_byron() {
        local prof="${1:-default}"; shift
        local target_dir="${1:-./keys}"
        prof=$(cluster_sh resolve-profile "$prof")

        local start_future_offset='1 minute' start_time
        start_time="$(date +%s -d "now + ${start_future_offset}")"

        local byron_params_tmpfile

        byron_params_tmpfile=$(mktemp --tmpdir)
        profile_byron_protocol_params "$prof" >"$byron_params_tmpfile"

        args=(
        --genesis-output-dir           "$target_dir"
        --start-time                   "$start_time"
        --protocol-parameters-file     "$byron_params_tmpfile"

        --k                            $(mcjq .genesis_params.parameter_k)
        --protocol-magic               $(mcjq .genesis_params.protocol_magic)
        --secret-seed                  $(mcjq .genesis_params.secret)
        --total-balance                $(mcjq .genesis_params.total_balance)

        --n-poor-addresses             $(mcjq .genesis_params.n_poors)
        --n-delegate-addresses         $(mcjq '(.node_names | length)')
        --delegate-share               $(mcjq .genesis_params.delegate_share)
        --avvm-entry-count             $(mcjq .genesis_params.avvm_entries)
        --avvm-entry-balance           $(mcjq .genesis_params.avvm_entry_balance)
        )

        mkdir -p "$target_dir"
        target_files=(
                "$target_dir"/genesis.json
                "$target_dir"/delegate-keys.*.key
                "$target_dir"/delegation-cert.*.json
        )
        rm -rf -- ./"$target_dir"
        cardano-cli genesis --real-pbft "${args[@]}" "$@"
        rm -f "$byron_params_tmpfile"
        cardano-cli print-genesis-hash \
                --genesis-json "$target_dir/genesis.json" |
                tail -1 > "$target_dir"/GENHASH

        echo "--( generated genesis for $prof in:  $target_dir"
}

genesis_check_deployed_age() {
        # test $# = 3 || failusage "check-genesis-age HOST SLOTLEN K"
        local core="${1:-node-0}" slotlen="${2:-20}" k="${3:-2160}" startTime now
        startTime=$(nixops ssh ${core} \
          jq .startTime $(nixops ssh ${core} \
                  jq .GenesisFile $(nixops ssh ${core} -- \
                          pgrep -al cardano-node |
                                  sed 's_.* --config \([^ ]*\) .*_\1_')))
        now=$(date +%s)
        local age_t=$((now - startTime))
        local age_slots=$((age_t / slotlen))
        local remaining=$((k * 2 - age_slots))
        cat <<EOF
---| Genesis:  .startTime=${startTime}  now=${now}  age=${age_t}s  slotlen=${slotlen}
---|           slot age=${age_slots}  k=${k}  remaining=${remaining}
EOF
        if   test "${age_slots}" -ge $((k * 2))
        then fail "genesis is too old"
        elif test "${age_slots}" -ge $((k * 38 / 20))
        then fail "genesis is dangerously old, slots remaining: ${remaining}"
        fi
}

###
### Aux
###
goggles_fn='cat'

goggles_ip() {
        sed "$(jq --raw-output '.
              | .local_ip  as $local_ip
              | .public_ip as $public_ip
              | ($local_ip  | map ("s_\(.local_ip  | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g")) +
                ($public_ip | map ("s_\(.public_ip | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g"))
              | join("; ")
              ' last-meta.json)"
}

goggles() {
        ${goggles_fn}
}
export -f goggles goggles_ip
