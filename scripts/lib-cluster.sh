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
op_init_cluster() {
        local node_count="${1?USAGE:  init-cluster NODECOUNT [PROTOCOL-ERA=byron]}"
        local era="${2:-byron}"
        if test $((node_count + 0)) -ne ${node_count}
        then fail "this operation requires a node count as an integer argument."
        fi
        jq --null-input ' .
| { slot_length:           20
  , parameter_k:           2160
  , protocol_magic:        459045235
  , secret:                2718281828
  , total_balance:         8000000000000000
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

| { txs:                   50000
  , payload:               100
  , tx_io_arities:         [1, 2, 4, 8, 16]
  , tx_fee:                10000000
  , tps:                   100
  , init_cooldown:         100
  , nodes:                 [ "a", "b", "c", "d"
                           , "e", "f", "g", "h"
                           , "i", "j", "k", "l"]
  ## Note:  the above is a little ridiculous, but better than hard-coding.
  ##  The alternative is quite esoteric -- we have to evaluate the Nixops
  ##  deployment in a highly non-trivial manner and query that.

  } as $defprof
| ($defprof | .tx_io_arities)
| map
  ( . as $io_arity
  | { "distrib'${node_count}'-\($defprof | .txs)tx-\($defprof | .payload)b-\($io_arity)i-\($io_arity)o-\($defprof | .tps)tps":
      { tx_count:          ($defprof | .txs)
      , add_tx_size:       ($defprof | .payload)
      , inputs_per_tx:     $io_arity
      , outputs_per_tx:    $io_arity
      , tx_fee:            ($defprof | .tx_fee)
      , tps:               ($defprof | .tps)
      }})

| { meta:
    { node_names:          ($defprof | .nodes | .[:'${node_count}'])
    ## The first entry is the defprof defprof.
    , default_profile:     (.[0] | (. | keys) | .[0])
    , genesis_params:      ($common_genesis_params
                            + (if $era_genesis_params | has("'${era}'")
                               then $era_genesis_params | .["'${era}'"]
                               else error("Unknown protocol era: '${era}'")
                               end))
    }

  ## A special profile for quick testing.
  , "smoke-test":
    { tx_count:            100
    , add_tx_size:         1
    , inputs_per_tx:       1
    , outputs_per_tx:      1
    , tx_fee:              ($defprof | .tx_fee)
    , tps:                 100
    , init_cooldown:       0
    }}
  + (. | add)' > ${clusterfile}
}

op_check_genesis_age() {
        # test $# = 3 || failusage "check-genesis-age HOST SLOTLEN K"
        local core="${1:-a}" slotlen="${2:-20}" k="${3:-2160}" startTime now
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

op_genesis_byron() {
        local target_dir="${1:-./keys}"

        local start_future_offset='1 minute' start_time
        start_time="$(${DATE} -d "now + ${start_future_offset}" +%s)"

        local protocol_params parameter_k protocol_magic n_poors n_delegates
        local total_balance delegate_share avvm_entries avvm_entry_balance
        local not_so_secret

        protocol_params='scripts/protocol-params.json'
        parameter_k=2160
        protocol_magic=459045235
        n_poors=128
        n_delegates=$(jq '(.meta.node_names | length)' \
                      "$(dirname "$0")/../benchmarking-cluster-params.json")
        total_balance=8000000000000000
        delegate_share=0.9
        avvm_entries=128
        avvm_entry_balance=10000000000000
        not_so_secret=2718281828

        args=(
                --genesis-output-dir           "${tmpdir}"
                --start-time                   "${start_time}"
                --protocol-parameters-file     "${protocol_params}"
                --k                            ${parameter_k}
                --protocol-magic               ${protocol_magic}
                --n-poor-addresses             ${n_poors}
                --n-delegate-addresses         ${n_delegates}
                --total-balance                ${total_balance}
                --delegate-share               ${delegate_share}
                --avvm-entry-count             ${avvm_entries}
                --avvm-entry-balance           ${avvm_entry_balance}
                --secret-seed                  ${not_so_secret}
        )

        mkdir -p "${target_dir}"
        target_files=(
                "${target_dir}"/genesis.json
                "${target_dir}"/delegate-keys.*.key
                "${target_dir}"/delegation-cert.*.json
        )
        rm -f -- ${target_files[*]}
        cardano-cli genesis --real-pbft "${args[@]}" "$@"
        cardano-cli print-genesis-hash \
                --genesis-json "${target_dir}/genesis.json" |
                tail -1 > "${target_dir}"/GENHASH
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
