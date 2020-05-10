#!/usr/bin/env bash
# shellcheck disable=2086

clusterfilename='benchmarking-cluster-params.json'
clusterfile=$(realpath "$(dirname "$0")/../${clusterfilename}")

clusterfile_init() {
        test -f "${clusterfile}" ||
                fail "missing cluster benchmark parameters, consider running:  $(basename "${self}") init NODECOUNT"
}

cluster_sh() {
        local cmd="$1"; shift
        case "$cmd" in
                producers )    rrjq "${clusterfile}" ' .
                                     | (.meta.nodeNames | join(" "))';;
                profiles )     rrjq "${clusterfile}" ' .
                                     | del (.meta)
                                     | keys_unsorted
                                     | join(" ")';;
                has-profile )  rjqtest "${clusterfile}" '
                                     .["'$1'"] != null';;
                resolve-profile )
                               rrjq "${clusterfile}" '.
                                     | if "'$1'" == "default"
                                       then .meta.defaultProfile
                                       else if . | has("'$1'") then "'$1'"
                                       else error("Unknown profile: '$1'")
                                       end end' || fail "profile unknown";;
                * ) fail "unknown query: $1";;
        esac
}

op_init_cluster() {
        local node_count="${1:-3}"
        if test $((node_count + 0)) -ne ${node_count}
        then fail "this operation requires a node count as an integer argument."
        fi
        jq --null-input ' .
| { "txs":            50000
  , "payload":        100
  , "tx_io_arities":  [1, 2, 4, 8, 16]
  , "tx_fee":         10000000
  , "tps":            100

  ## WARNING:  this is a little ridiculous, but better than hard-coding.
  ##  The alternative is quite esoteric -- we have to evaluate the Nixops
  ##  deployment in a highly non-trivial manner and query that.
  , "nodes":          [ "a", "b", "c", "d"
                      , "e", "f", "g", "h"
                      , "i", "j", "k", "l"]
  } as $default
| ($default | .tx_io_arities)
| map
  ( . as $io_arity
  | { "distrib'${node_count}'-\($default | .txs)tx-\($default | .payload)b-\($io_arity)i-\($io_arity)o-\($default | .tps)tps":
      { "txCount":         ($default | .txs)
      , "addTxSize":       ($default | .payload)
      , "inputsPerTx":     $io_arity
      , "outputsPerTx":    $io_arity
      , "txFee":           ($default | .tx_fee)
      , "tps":             ($default | .tps)
      }})
| { "meta":
    { "nodeCount": '${node_count}'
    , "nodeNames": ($default | .nodes | .[:'${node_count}'])
    ## The first entry is the default default.
    , "defaultProfile": (.[0] | (. | keys) | .[0])
    }}
  + (. | add)' > ./${clusterfile}
}
