#!/usr/bin/env bash

paramsfilename='benchmarking-cluster-params.json'
paramsfile=$(realpath "$(dirname "$0")/../${paramsfilename}")

params_check() {
        test -f "${paramsfile}" ||
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
def profile_name($gtor; $gsis):
  [ "dist'${node_count}'"
  , ($gtor.txs         | tostring) + "tx"
  , ($gtor.add_tx_size | tostring) + "b"
  , ($gtor.tps         | tostring) + "tps"
  , ($gtor.io_arity    | tostring) + "io"
  , ($gsis.max_block_size | . / 1000
                       | tostring) + "kblk"
  ] | join("-");

  [ { txs: 50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 16, tps: 100 }
  ] as $generator_profiles

| [ { name: "short"
    , txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100
    }
  , { name: "small"
    , txs: 1000,  add_tx_size: 100, io_arity: 1,  tps: 100
    , init_cooldown: 25, finish_patience: 5 }
  , { name: "small-32k"
    , txs: 1000,  add_tx_size: 100, io_arity: 1,  tps: 100
    , init_cooldown: 25, finish_patience: 5
    , genesis_profile: 6
    }
  , { name: "edgesmoke"
    , txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100
    , init_cooldown: 25, finish_patience: 2 }
  , { name: "smoke"
    , txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100
    , init_cooldown: 25, finish_patience: 5 }
  ] as $generator_aux_profiles

| [ { max_block_size: 2000000 }
  , { max_block_size: 1000000 }
  , { max_block_size:  500000 }
  , { max_block_size:  250000 }
  , { max_block_size:  128000 }
  , { max_block_size:   64000 }
  , { max_block_size:   32000 }
  ] as $genesis_profiles

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
| [[ ($generator_profiles
     | ( $generator_aux_profiles | map(.name | {key: ., value: null})
       | from_entries) as $aux_names
     | map (select ((.name // "") | in($aux_names) | not)))
   , $genesis_profiles
   ]
   | combinations
   ]
  + ($generator_aux_profiles
    | map ([ . | del(.genesis_profile)
           , $genesis_profiles[.genesis_profile // 0]
             // error("in aux profile \(.name):  no genesis profile with index \(.genesis_profile)")]))
| map
  ( .[0] as $generator
  | .[1] as $genesis
  | { "\($generator.name // profile_name($generator; $genesis))":
      { generator:
        ($generator_defaults +
         ($generator | del(.name) | del(.txs) | del(.io_arity)
                     | del(.finish_patience)) +
        { tx_count:        $generator.txs
        , inputs_per_tx:   $generator.io_arity
        , outputs_per_tx:  $generator.io_arity
        })
      , run_params:
        ($run_defaults +
        { finish_patience:
            ## TODO:  fix ugly
            ($generator.finish_patience // $run_defaults.finish_patience)
        })
      , genesis_params:
        ($common_genesis_params +
         ($era_genesis_params."'"$era"'" // error("era is null")) +
         $genesis_defaults +
         $genesis)
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
    , aux_profiles:        ($generator_aux_profiles | map(.name))
    }}
  + (. | add)
' > ${paramsfile}
}

## Paramsfile JQ
parmjq() {
        local q=$1; shift
        jq "$q" "${paramsfile}" "$@"
}

## Raw Paramsfile JQ
rparmjq() {
        local q=$1; shift
        parmjq "$q" --raw-output "$@"
}

## Raw Paramsfile .meta JQ
parmetajq() {
        local q=$1; shift
        rparmjq ".meta | $q" "$@"
}

## Raw Paramsfile .meta.genesis JQ
parmgenjq() {
        local q=$1; shift
        rparmjq ".meta.genesis | $q" "$@"
}

## Paramsfile JQ TEST
parmjqtest() {
        parmjq "$1" --exit-status >/dev/null
}

query_profiles() {
        params profiles | sed 's_ _\n_g' |
        jq . --raw-input |
        jq '( map ({key: ., value: 1}) | from_entries) as $profs
            | $params[0] | to_entries
            | map( select(.key | in($profs))
                 | . + { value: (.value + { name: .key }) }
                 | .value)
            | map( select('"$1"')
                 | .name)
            | join(" ")
           ' --slurp --slurpfile params "${paramsfile}" --raw-output
}

params() {
        dprint "params:  ${*@Q}"

        local cmd="$1"; shift
        case "$cmd" in
                producers )    rparmjq ' .
                                      | (.meta.node_names | join(" "))';;
                profiles )     rparmjq ' .
                                      | delpaths (.meta.aux_profiles | map([.]))
                                      | del (.meta)
                                      | keys_unsorted
                                      | join(" ")';;
                query-profiles )
                               query_profiles "$1";;
                has-profile )  parmjqtest '.["'$1'"] != null';;
                resolve-profile )
                               rparmjq ' .
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
