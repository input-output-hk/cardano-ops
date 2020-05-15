#!/usr/bin/env bash
# shellcheck disable=2086

clusterfilename='benchmarking-cluster-params.json'
clusterfile=$(realpath "$(dirname "$0")/../${clusterfilename}")

clusterfile_init() {
        test -f "${clusterfile}" ||
                fail "missing cluster benchmark parameters, consider running:  $(basename "${self}") init NODECOUNT"
}

## Clusterfile JQ
cjq() {
        jq "$1" "${clusterfile}"
}

## Raw Clusterfile JQ
rcjq() {
        jq "$1" "${clusterfile}" --raw-output
}

mcjq() {
        rcjq ".meta | $1"
}

pcjq() {
        rcjq "del(.meta)
             | if has(\"$1\") then .[\"$1\"] $2
               else error(\"Can't query unknown profile $1 using $2\") end"
}

## Clusterfile JQ TEST
cjqtest() {
        jq "$1" "${clusterfile}" --exit-status >/dev/null
}

cluster_sh() {
        dprint "cluster_sh:  ${*@Q}"

        local cmd="$1"; shift
        case "$cmd" in
                producers )    rcjq ' .
                                      | (.meta.node_names | join(" "))';;
                profiles )     rcjq ' .
                                      | del (.meta) | del (.["smoke-test"])
                                      | keys_unsorted
                                      | join(" ")';;
                has-profile )  cjqtest '.["'$1'"] != null';;
                resolve-profile )
                               rcjq ' .
                                      | if "'$1'" == "default"
                                        then .meta.default_profile
                                        else if . | has("'$1'") then "'$1'"
                                        else error("Unknown profile: '$1'")
                                        end end' || fail "profile unknown";;
                * ) fail "unknown query: $1";;
        esac
}

cluster_last_meta_tag() {
        local meta=./last-meta.json tag dir meta2
        jq . "${meta}" >/dev/null || fail "malformed run metadata: ${meta}"

        tag=$(jq --raw-output .meta.tag "${meta}")
        test -n "${tag}" || fail "bad tag in run metadata: ${meta}"

        dir="./runs/${tag}"
        test -d "${dir}" ||
                fail "bad tag in run metadata: ${meta} -- ${dir} is not a directory"
        meta2=${dir}/meta.json
        jq --exit-status . "${meta2}" >/dev/null ||
                fail "bad tag in run metadata: ${meta} -- ${meta2} is not valid JSON"

        test "$(realpath ./last-meta.json)" = "$(realpath "${meta2}")" ||
                fail "bad tag in run metadata: ${meta} -- ${meta2} is different from ${meta}"
        echo "${tag}"
}

## This sets up the cluster configuration file,
## 'benchmarking-cluster-params.json', for:
##   1. a given protocol era, and
##   2. a given number of nodes.
##
## The schema is:
##   1. keys (except "meta") map to tx generator profiles,
##   2. the "meta" key maps to common cluster configuration,
##      including, but not limited to:
##      - default tx generator profile name
##      - count and the names of producer nodes
##      - genesis parameters
op_init_params() {
        local node_count="${1?USAGE:  init-cluster NODECOUNT [PROTOCOL-ERA=byron]}"
        local era="${2:-byron}"
        if test $((node_count + 0)) -ne ${node_count}
        then fail "this operation requires a node count as an integer argument."
        fi
        jq --null-input '
def profile_name($prof):
  [ "dist'${node_count}'"
  , ($prof.txs      | tostring) + "tx"
  , ($prof.payload  | tostring) + "b"
  , ($prof.io_arity | tostring) + "i"
  , ($prof.io_arity | tostring) + "o"
  , ($prof.tps      | tostring) + "tps"
  ] | join("-");

  [ { txs: 50000, payload: 100, io_arity: 1,  tps: 100 }
  , { txs: 50000, payload: 100, io_arity: 2,  tps: 100 }
  , { txs: 50000, payload: 100, io_arity: 4,  tps: 100 }
  , { txs: 50000, payload: 100, io_arity: 8,  tps: 100 }
  , { txs: 50000, payload: 100, io_arity: 16, tps: 100 }
  , { txs: 10000, payload: 100, io_arity: 1,  tps: 100, name: "short" }
  , { txs: 100,   payload: 100, io_arity: 1,  tps: 100, name: "smoke-test"
    , init_cooldown: 0, finish_patience: 3 }
  ] as $profile_specs

| [ { max_block_size: 2000000 }
  ] as $max_block_sizes

| { parameter_k:             2160
  , protocol_magic:          459045235
  , secret:                  2718281828
  , total_balance:           8000000000000000
  } as $common_genesis_params

| { byron:
    { n_poors:               128
    , n_delegates:           '${node_count}'
      ## Note, that the delegate count doesnt have to match cluster size.
    , delegate_share:        0.9
    , avvm_entries:          128
    , avvm_entry_balance:    10000000000000
    }
  } as $era_genesis_params

  ## The profile-invariant part.
| { init_cooldown:         100
  , finish_patience:       5
  , slot_duration:         20000
  , tx_fee:                10000000
  , nodes:                 [range(0; 16)] | map ("node-\(.)")
  ## Note:  the above is a little ridiculous, but better than hard-coding.
  ##  The alternative is quite esoteric -- we have to evaluate the Nixops
  ##  deployment in a highly non-trivial manner and query that.

  } as $common

## For all IO arities and block sizes:
| [[ $profile_specs
   , $max_block_sizes
   ]
   | combinations
   | add                   ## Combine layers:  generic and blksizes
   ]
| map
  ( . as $prof
  | { "\($prof.name // profile_name($prof))":
      { generator:
        { tx_count:        $prof.txs
        , add_tx_size:     $prof.payload
        , inputs_per_tx:   $prof.io_arity
        , outputs_per_tx:  $prof.io_arity
        , tx_fee:          $common.tx_fee
        , tps:             $prof.tps
        , init_cooldown:   ($prof.init_cooldown   // $common.init_cooldown)
        }
      , run_params:
        { finish_patience: ($prof.finish_patience // $common.finish_patience)
        }
      , genesis_params:
        { max_block_size:  $prof.max_block_size
        , slot_duration:   $common.slot_duration
        }
      }}
  )
| { meta:
    { node_names:          $common.nodes[:'${node_count}']
    ## The first entry is the defprof defprof.
    , default_profile:     (.[0] | (. | keys) | .[0])
    , genesis_params:      ($common_genesis_params
                            + (if $era_genesis_params | has("'${era}'")
                               then $era_genesis_params | .["'${era}'"]
                               else error("Unknown protocol era: '${era}'")
                               end))
    }}
  + (. | add)
' > ${clusterfile}
}

op_check_genesis_age() {
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

## Genesis Clusterfile JQ
gcjq() {
        rcjq ".meta.genesis_params | $1"
}

byron_protocol_params() {
        local prof=$1
        jq <<<'{
    "heavyDelThd": "300000000000",
    "maxBlockSize": "'"$(pcjq "${prof}" .genesis_params.max_block_size)"'",
    "maxHeaderSize": "2000000",
    "maxProposalSize": "700",
    "maxTxSize": "4096",
    "mpcThd": "20000000000000",
    "scriptVersion": 0,
    "slotDuration": "'"$(pcjq "${prof}" .genesis_params.slot_duration)"'",
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

op_genesis_byron() {
        local prof="${1:-default}"
        prof=$(cluster_sh resolve-profile "$prof")
        local target_dir="${1:-./keys}"

        local start_future_offset='1 minute' start_time
        start_time="$(date +%s -d "now + ${start_future_offset}")"

        local byron_params_tmpfile

        byron_params_tmpfile=$(mktemp --tmpdir)
        byron_protocol_params "$prof" >"$byron_params_tmpfile"

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
