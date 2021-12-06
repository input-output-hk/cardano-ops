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

        realpath "$__BENCH_BASEPATH"/../topologies/bench-${type}-${node_count}.nix
}

topology_id_pool_density_map() {
        local topology_file=${1:-}

        nix-instantiate --strict --eval \
          -E '__toJSON (__listToAttrs
                        (map (x: { name = toString x.nodeId;
                                  value = if (x.pools or 0) == null then 0 else x.pools or 0; })
                             (import '"${topology_file}"').coreNodes))' |
          sed 's_\\__g; s_^"__; s_"$__'
}

id_pool_map_composition() {
        local ids_pool_map=$1

        jq '.
           | to_entries
           | length                                as $n_hosts
           | map (select (.value != 0))            as $pools
           | ($pools | map (select (.value == 1))) as $singular_pools
           | ($pools | map (select (.value  > 1))) as $dense_pools
           | ($singular_pools | length)            as $n_singular_hosts
           | map (select (.value == 0)) as $bfts
           | { n_hosts:          $n_hosts
             , n_bft_hosts:      ($bfts  | length)
             , n_singular_hosts: ($singular_pools | length)
             , n_dense_hosts:    ($dense_pools    | length)
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
        local node_count="${1?USAGE:  init-cluster NODECOUNT [PROTOCOL-ERA=shelley] [TOPOLOGY=dense|eu-central-1]}"
        local era="${2:-shelley}"
        local topology="${3:-dense}"
        if test $((node_count + 0)) -ne $node_count
        then fail "this operation requires a node count as an integer argument."
        fi

        local topology_file id_pool_map composition
        topology_file=$(get_topology_file "$topology" "$node_count")
        oprint "re-deriving cluster parameters for size $node_count, era $era, topology $topology_file, ops commit $(git rev-parse HEAD | head -c7)"

        id_pool_map=$(topology_id_pool_density_map "$topology_file")
        composition=$(id_pool_map_composition "$id_pool_map")

        local args=(--argjson   compo        "$composition"
                    --slurpfile def_byron    'bench/genesis-byron-mainnet.json'
                    --slurpfile def_shelley  'bench/genesis-shelley-mainnet.json'
                    --slurpfile def_alonzo   'bench/genesis-alonzo-mainnet.json'
                    --arg       topology     "$topology"
                    --arg       era          "$era")
        jq "${args[@]}" '
include "profile-definitions" { search: "bench" };

  { byron:    $def_byron[0]
  , shelley:  $def_shelley[0]
  , alonzo:   $def_alonzo[0]
  } as $defaults_ext
| genesis_defaults($era; $compo; $defaults_ext) as $genesis_defaults
| generator_defaults($era)                      as $generator_defaults
| node_defaults($era)                           as $node_defaults

| (aux_profiles($compo) | map(.name | {key: ., value: null}) | from_entries)
                                         as $aux_names

## For all IO arities and block sizes:
| profiles
| . +
  ( aux_profiles($compo)
  | map ({ name:      .name
         , genesis:   ($genesis_defaults   * ( .genesis   // {} ))
         , generator: ($generator_defaults * ( .generator // {} ))
         , node:      ($node_defaults      * ( .node      // {} ))
         }))
| map
  ( ($genesis_defaults    * ( .genesis   // {} ))  as $gsis
  | ($generator_defaults  * ( .generator // {} ))  as $gtor
  | ($node_defaults       * ( .node      // {} ))  as $node
  | era_tolerances($era; $gsis)                    as $tolr
  | { description:
        (.desc // .description // "")
    , genesis:
        ($gsis * derived_genesis_params($era; $compo; $gtor; $gsis; $node))
    , generator:
        ($gtor * derived_generator_params($era; $compo; $gtor; $gsis; $node))
    , node:
        ($node * derived_node_params($era; $compo; $gtor; $gsis; $node))
    , tolerances:
        ($tolr * derived_tolerances($era; $compo; $gtor; $gsis; $node; $tolr))
    }                                    as $prof
  | { "\(.name //
         profile_name($compo; $prof.genesis; $prof.generator; $prof.node;
                      $genesis_defaults))":
      ($prof
       | delpaths ([ ["generator", "epochs"]
                   , ["generator", "finish_patience"]]))
    }
  )
| { meta:
    { era:                 $era
    , topology:            $topology
    , node_names:          ( [range(0; 100)]
                           | map ("node-\(.)")
                           | .[:$compo.n_hosts])
    ## Note:  the above is a little ridiculous, but better than hard-coding.
    ##  The alternative is quite esoteric -- we have to evaluate the Nixops
    ##  deployment in a highly non-trivial manner and query that.

    ## The first entry is the defprof defprof.
    , default_profile:     (.[0] | (. | keys) | .[0])
    , aux_profiles:        (aux_profiles($compo) | map(.name))
    , composition:         $compo
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

list_profiles() {
    rparmjq 'del(.meta)
            | to_entries
            | sort_by(.value.description)
            | (map (.key | length) | max | . + 1) as $maxlen
            | map("\(.key
                    | " " * ($maxlen - length))\(.key): \(.value.description)")
            | .[]'
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
