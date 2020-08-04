#!/usr/bin/env bash

paramsfilename='benchmarking-cluster-params.json'
paramsfile=$(realpath "$(dirname "$0")/../${paramsfilename}")

params_check() {
        test -f "${paramsfile}" ||
                fail "missing cluster benchmark parameters, consider running:  $(basename "${self}") init NODECOUNT"
}

get_topology_file() {
        local type node_count
        type=${1:-$(parmetajq '.topology')}
        node_count=${2:-$(parmetajq '.node_names | length')}

        realpath "$__BENCH_BASEPATH"/../topologies/bench-txgen-${type}-${node_count}.nix
}

params_recreate_cluster() {
        local n=$1 prof=${2:-default}

        oprint "reconfiguring cluster to size $n, profile $prof"
        deploystate_destroy

        params_init "$n"
        deploystate_create

        ## This can be done only after the paramsfile is updated.
        prof=$(params resolve-profile "$prof")
        profile_deploy "$prof"
}

topology_id_pool_map() {
        local topology_file=${1:-}

        nix-instantiate \
          --strict --eval \
          -E '__toJSON (__listToAttrs
                        (map (x: { name = toString x.nodeId;
                                  value = __hasAttr "stakePool" x; })
                             (import '"${topology_file}"').coreNodes))' |
          sed 's_\\__g; s_^"__; s_"$__'
}

id_pool_map_composition() {
        local ids_pool_map=$1

        jq '.
           | to_entries
           | { n_pools:         (map (select (.value))       | length)
             , n_bft_delegates: (map (select (.value | not)) | length)
             , n_total:         length
             }
           ' <<<$ids_pool_map --compact-output
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
        local node_count="${1?USAGE:  init-cluster NODECOUNT [PROTOCOL-ERA=shelley|byron] [TOPOLOGY=distrib|eu-central-1]}"
        local era="${2:-shelley}"
        local topology="${3:-distrib}"
        if test $((node_count + 0)) -ne $node_count
        then fail "this operation requires a node count as an integer argument."
        fi

        local topology_file id_pool_map composition
        topology_file=$(get_topology_file "$topology" "$node_count")
        oprint "re-deriving cluster parameters for size $node_count, era $era, topology $topology_file"

        id_pool_map=$(topology_id_pool_map "$topology_file")
        composition=$(id_pool_map_composition "$id_pool_map")

        local args=(--argjson composition "$composition"
                    --arg     topology    "$topology"
                    --arg     era         "$era")
        jq "${args[@]}" '
include "profile-definitions" { search: "bench" };

def profile_name($gtor; $gsis):
  [ "dist\($composition.n_total)"
  , ($gtor.txs         | tostring) + "tx"
  , ($gtor.add_tx_size | tostring) + "b"
  , ($gtor.tps         | tostring) + "tps"
  , ($gtor.io_arity    | tostring) + "io"
  , ($gsis.max_block_size | . / 1000
                       | tostring) + "kb"
  ] | join("-");

  era_generator_profiles($era)           as $generator_profiles
| era_genesis_profiles($era)             as $genesis_profiles

| era_generator_params($era)             as $generator_params
| era_genesis_params($era; $composition) as $genesis_params

## For all IO arities and block sizes:
| [[ $genesis_profiles
   , ($generator_profiles
     | ( generator_aux_profiles | map(.name | {key: ., value: null})
       | from_entries) as $aux_names
     | map (select ((.name // "") | in($aux_names) | not)))
   ]
   | combinations
   ]
| . +
  ( generator_aux_profiles
  | map ([ $genesis_profiles[.genesis_profile // 0]
           // error("in aux profile \(.name):
                     no genesis profile with index \(.genesis_profile)")
         , . | del(.genesis_profile)]))
| map
  ( ($genesis_params + .[0])       as $genesis
  | .[1]                           as $generator
  | era_tolerances($era; $genesis) as $tolerances
  | { "\($generator.name // profile_name($generator; $genesis))":
      { generator:
        ($generator_params +
         ($generator | del(.name) | del(.txs) | del(.io_arity)
                     | del(.finish_patience)) +
        { tx_count:        $generator.txs
        , inputs_per_tx:   $generator.io_arity
        , outputs_per_tx:  $generator.io_arity
        })
      , genesis: $genesis
      , tolerances:
        ($tolerances +
        { finish_patience:
            ## TODO:  fix ugly
            ($generator.finish_patience // $tolerances.finish_patience)
        })
      }}
  )
| { meta:
    { era:                 $era
    , topology:            $topology
    , node_names:          ( [range(0; 16)]
                           | map ("node-\(.)")
                           | .[:$composition.n_total])
    ## Note:  the above is a little ridiculous, but better than hard-coding.
    ##  The alternative is quite esoteric -- we have to evaluate the Nixops
    ##  deployment in a highly non-trivial manner and query that.

    ## The first entry is the defprof defprof.
    , default_profile:     (.[0] | (. | keys) | .[0])
    , aux_profiles:        (generator_aux_profiles | map(.name))
    }}
  + (. | add)
' > ${paramsfile} --null-input
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

get_era() {
        parmetajq '.era'
}

query_profiles() {
        params profiles | words_to_lines |
        jq . --raw-input |
        jq 'def among($setarr):
              tostring | in ($setarr | map({ key: tostring, value: 1}) | from_entries);
            def matrix_blks_by_ios($blks; $ios):
              (.generator.inputs_per_tx | among($blks)) and (.genesis.max_block_size | among($ios));

            ( map ({key: ., value: 1}) | from_entries) as $profs
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
                all-machines )
                               echo "explorer $(params producers)";;
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
