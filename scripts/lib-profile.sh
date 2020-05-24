#!/usr/bin/env bash
# shellcheck disable=2086

## Profile JQ
profjq() {
        local prof=$1 q=$2; shift 2
        rparmjq "del(.meta)
                | if has(\"$prof\") then (.\"$prof\" | $q)
                  else error(\"Can't query unknown profile $prof using $q\") end
                " "$@"
}

profgenjq()
{
        local prof=$1 q=$2; shift 2
        profjq "$prof" ".genesis | ($q)" "$@"
}

genesisjq()
{
        local q=$1; shift
        jq "$q" ./keys/genesis-meta.json "$@"
}

profile_byron_protocol_params() {
        local prof=$1
        jq <<<'{
    "heavyDelThd": "300000000000",
    "maxBlockSize": "'"$(profgenjq "${prof}" .max_block_size)"'",
    "maxHeaderSize": "2000000",
    "maxProposalSize": "700",
    "maxTxSize": "4096",
    "mpcThd": "20000000000000",
    "scriptVersion": 0,
    "slotDuration": "'"$(profgenjq "${prof}" .slot_duration)"'",
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
        local prof="${1:-default}"
        local target_dir="${2:-./keys}"
        prof=$(params resolve-profile "$prof")

        local start_future_offset='1 minute' start_time
        start_time="$(date +%s -d "now + ${start_future_offset}")"

        local byron_params_tmpfile

        byron_params_tmpfile=$(mktemp --tmpdir)
        profile_byron_protocol_params "$prof" >"$byron_params_tmpfile"

        args=(
        --genesis-output-dir         "$target_dir"
        --start-time                 "$start_time"
        --protocol-parameters-file   "$byron_params_tmpfile"

        --k                          $(profgenjq "$prof" .parameter_k)
        --protocol-magic             $(profgenjq "$prof" .protocol_magic)
        --secret-seed                $(profgenjq "$prof" .secret)
        --total-balance              $(profgenjq "$prof" .total_balance)

        --n-poor-addresses           $(profgenjq "$prof" .n_poors)
        --n-delegate-addresses       $(profgenjq "$prof" .n_delegates)
        --delegate-share             $(profgenjq "$prof" .delegate_share)
        --avvm-entry-count           $(profgenjq "$prof" .avvm_entries)
        --avvm-entry-balance         $(profgenjq "$prof" .avvm_entry_balance)
        )

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"
        cardano-cli genesis --real-pbft "${args[@]}"
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

profile_deploy() {
        local prof="${1:-default}" include=()
        prof=$(params resolve-profile "$prof")

        ## Determine if genesis update is necessary:
        ## 1. old enough?
        ## 2. profile incompatible?
        regenesis_causes=()

        if test -n "${force_genesis}"
        then regenesis_causes+=('--genesis'); fi

        if   ! genesisjq . >/dev/null 2>&1
        then regenesis_causes+=('missing-or-malformed-genesis-metadata')
        else
             if ! check_genesis_age "$(genesisjq .start_time)"
             then regenesis_causes+=('local-genesis-old-age'); fi
             if   njqtest "
                  $(genesisjq .params) !=
                  $(profjq "${prof}" .genesis)"
             then regenesis_causes+=('profile-requires-new-genesis'); fi; fi

        if test -n "${regenesis_causes[*]}"
        then oprint "regenerating genesis, because:  ${regenesis_causes[*]}"
             profile_genesis_byron "$prof"; fi

        redeploy_causes=(mandatory)
        include=('explorer')

        if   test ! -f "${deployfile['explorer']}"
        then redeploy_causes+=(missing-explorer-deployfile)
             include+=('explorer')
        elif ! depljq 'explorer' . >/dev/null 2>&1
        then redeploy_causes+=(malformed-explorer-deployfile)
             include+=('explorer')
        elif njqtest "
             ($(depljq 'explorer' .profile)         != \"$prof\") or
             ($(depljq 'explorer' .profile_content) != $(profjq "$prof" .))"
        then redeploy_causes+=(new-profile)
             include+=('explorer')
        elif njqtest "
             $(genesisjq .params 2>/dev/null || echo '"missing"') !=
             $(depljq 'explorer' .profile_content.genesis)"
        then redeploy_causes+=(genesis-params-explorer)
             include+=('explorer')
        elif njqtest "
             $(genesisjq .hash 2>/dev/null || echo '"missing"') !=
             $(depljq 'explorer' .genesis_hash)"
        then redeploy_causes+=(genesis-hash-explorer)
             include+=('explorer'); fi


        if test ! -f "${deployfile['producers']}"
        then redeploy_causes+=(missing-producers-deployfile)
             include+=($(params producers))
        elif ! depljq 'producers' . >/dev/null 2>&1
        then redeploy_causes+=(malformed-producers-deployfile)
             include+=($(params producers))
        elif njqtest "
             $(genesisjq .params 2>/dev/null || echo '"missing"') !=
             $(depljq 'producers' .profile_content.genesis)"
        then redeploy_causes+=(genesis-params-producers)
             include+=($(params producers))
        elif njqtest "
             $(genesisjq .hash 2>/dev/null || echo '"missing"') !=
             $(depljq 'producers' .genesis_hash)"
        then redeploy_causes+=(genesis-hash-producers)
             include+=($(params producers)); fi

        if test -n "${force_deploy}"
        then redeploy_causes+=('--deploy')
             include=('explorer' $(params producers)); fi

        local final_include
        if test "${include[0]}" = "${include[1]:-}"
        then final_include=$(echo "${include[*]}" | sed 's/explorer explorer/explorer/g')
        else final_include="${include[*]}"; fi

        if test "$final_include" = "explorer $(params producers)"
        then qualifier='full'
        elif test "$final_include" = "$(params producers)"
        then qualifier='producers'
        else qualifier='explorer'; fi

        if test -z "${redeploy_causes[*]}" ||
           test -n "${no_deploy}"
        then return; fi

        oprint "redeploying, because:  ${redeploy_causes[*]}"
        deploylog=runs/$(timestamp).deploy.$qualifier.$prof.log
        deploystate_deploy_profile "$prof" "$final_include" "$deploylog"
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
