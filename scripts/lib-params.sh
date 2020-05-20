#!/usr/bin/env bash

clusterfilename='benchmarking-cluster-params.json'
clusterfile=$(realpath "$(dirname "$0")/../${clusterfilename}")

params_check() {
        test -f "${clusterfile}" ||
                fail "missing cluster benchmark parameters, consider running:  $(basename "${self}") init NODECOUNT"
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
params_init() {
        local node_count="${1?USAGE:  init-cluster NODECOUNT [PROTOCOL-ERA=byron]}"
        local era="${2:-byron}"
        if test $((node_count + 0)) -ne ${node_count}
        then fail "this operation requires a node count as an integer argument."
        fi
        jq --null-input '
def profile_name($prof):
  [ "dist'${node_count}'"
  , ($prof.txs         | tostring) + "tx"
  , ($prof.add_tx_size | tostring) + "b"
  , ($prof.io_arity    | tostring) + "i"
  , ($prof.io_arity    | tostring) + "o"
  , ($prof.tps         | tostring) + "tps"
  ] | join("-");

  [ { txs: 50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 16, tps: 100 }
  , { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100, name: "short" }
  , { txs: 1000,  add_tx_size: 100, io_arity: 1,  tps: 100, name: "small"
    , init_cooldown: 20, finish_patience: 3 }
  , { txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100, name: "smoke-test"
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

| { slot_duration:           20000
  } as $genesis_defaults

| { init_cooldown:           60
  , single_threaded:         true
  , tx_fee:                  10000000
  } as $generator_defaults

| { finish_patience:         5
  } as $run_defaults

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
        ($generator_defaults +
         ($prof | del(.finish_patience) | del(.io_arity) | del(.max_block_size)
                | del(.name) | del(.txs)) +
        { tx_count:        $prof.txs
        , inputs_per_tx:   $prof.io_arity
        , outputs_per_tx:  $prof.io_arity
        })
      , run_params:
        ($run_defaults +
        {
        })
      , genesis_params:
        ($genesis_defaults +
        { max_block_size:  $prof.max_block_size
        })
      }}
  )
| { meta:
    { node_names:          ( [range(0; 16)]
                           | map ("node-\(.)")
                           | .[:'${node_count}'])
    ## Note:  the above is a little ridiculous, but better than hard-coding.
    ##  The alternative is quite esoteric -- we have to evaluate the Nixops
    ##  deployment in a highly non-trivial manner and query that.

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
                                      | del (.meta)
                                      | del (."smoke-test")
                                      | del (."small")
                                      | del (."short")
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
