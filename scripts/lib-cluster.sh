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
