#!/usr/bin/env bash
# shellcheck disable=2207,2155,1007,1090
set -euo pipefail

__BENCH_BASEPATH=$(dirname "$(realpath "$0")")
. "$__BENCH_BASEPATH"/lib.sh
. "$__BENCH_BASEPATH"/lib-analyses.sh
. "$__BENCH_BASEPATH"/lib-analysis.sh
. "$__BENCH_BASEPATH"/lib-benchrun.sh
. "$__BENCH_BASEPATH"/lib-deploy.sh
. "$__BENCH_BASEPATH"/lib-genesis.sh
. "$__BENCH_BASEPATH"/lib-genesis-byron.sh
. "$__BENCH_BASEPATH"/lib-node-introspection.sh
. "$__BENCH_BASEPATH"/lib-node-mgmt.sh
. "$__BENCH_BASEPATH"/lib-params.sh
. "$__BENCH_BASEPATH"/lib-profile.sh
. "$__BENCH_BASEPATH"/lib-sanity.sh
. "$__BENCH_BASEPATH"/lib-sheets.sh
. "$__BENCH_BASEPATH"/lib-report.sh
. "$__BENCH_BASEPATH"/lib-tag.sh
###
### TODO
###
##  1. Automate genesis using cardano-node's Nix code. Param details are key.
##  2. Debug why kill -9 on the tx-generator removes _node's_ socket.
##  3. Make tx-generator exit on completion (DONE in WIP generator).
##  4. Maintain a local representation of deployed cluster state.
##  5. Sanity checks:
##     - genesis on explorer matches that of the producers

usage() {
        cat >&2 <<EOF
USAGE:  $(basename "$0") OPTIONS.. [OP=bench-profile] OP-ARGS..

  Options:

    --verbose             Print slightly more diagnostics.
    --trace               set -x
    --help                This short help.
    --help-full           Extended help.

  Main OPs:

    init-params N         Make a default ${paramsfile}
                            for a cluster with N nodes.
    reinit-params         Update ${paramsfile} for current 'cardano-ops'.

    deploy [PROF=default] Deploy the profile on the entire cluster.

    profiles [PROF=default]..
                          Run benchmark for a list of profiles.
    profiles all          Run benchmark across all profiles in ${paramsfile}.
    profiles 'jq(JQEXP)'  Run benchmark across all profiles matching JQEXP.
    profiles-jq JQEXP      ...

    list-profiles | ps    List available benchmark profiles.
    query-profiles JQEXP  Query profiles using 'jq'.

    list-runs | ls        List accumulated benchmark runs.
    fetch TAG             Fetch benchmark run logs.
    analyse TAG           Analyse benchmark run logs.
    mark-run-broken TAG   Mark a benchmark run as broken.
    package TAG           Package a benchmark run.

EOF
}

usage_extra() {
        cat >&2 <<EOF
  Extra options:

    --fast-unsafe         Ignore safety, go fast.  Deploys won't be made,
                            unprocessed logs will be lost.
    --pre-deploy          An extra deployment phase, before the genesis is generated.
    --deploy              Force redeployment, event if benchmarking
                            a single profile.
    --keep-genesis        Only update genesis start time & hash,
                            otherwise keeping it intact.
    --watch-deploy        Do not hide the Nixops deploy log.
    --cls                 Clear screen, before acting further.

  Other OPs:

    destroy               Release all cloud resources.
    recreate-cluster N [PROF=default]
                          Same as destroy + init N + deploy PROF.

    stop                  Stop the cluster, including all journald instances.

    archive-runs          Archive accumulated benchmark runs into ./runs-archive

    split-bench-log FILE  Decompose a combined generator + explorer node logfile
                            into message-classified streams, putting the result
                            into a directory named FILE.trace

    nodes CMD..           Run CMD either on forging nodes or the explorer.
    explorer CMD..
    fetch-utxo [NODE=explorer]
                          Fetch UTxO from NODE into FILE.

    jq-explorer [JQEXPR=.]
    jq-generator [JQEXPR=.]
    jq-nodes [JQEXPR=.]   Run JQ on the JSON logs of either forging nodes,
                            explorer+generator or just the generator.
                            Log entries are sorted by timestamp.

    blocks                'MsgBlock' messages seen by the explorer, incl. TxIds.
    grep                  For each host:  grep "\$1" /var/lib/cardano-node/logs/*
    pgrep                 For each host:  pgrep -fal \$*
    time                  For each host:  date +%s

EOF
}

verbose= debug= trace=
no_prebuild=
no_deploy=
no_analysis=
no_wait=
predeploy=
force_deploy=

self=$(realpath "$0")

main() {
        local jq_select='cat'
        local invocation=$(date --iso-8601=s --utc)":  $*"

        oprint "$invocation"
        echo "invocation" >> ./.bench_history

        while test $# -ge 1
        do case "$1" in
           --fast-unsafe | --fu ) no_deploy=t no_wait=t;;
           --no-prebuild | --skip-prebuild ) no_prebuild=t;;
           --no-deploy | --skip-deploy )     no_deploy=t;;
           --no-analysis | --skip-analysis ) no_analysis=t;;
           --deploy )             force_deploy=t;;
           --pre-deploy | --predeploy ) predeploy=t;;
           --select )             jq_select="jq 'select ($2)'"; shift;;

           --cls )                echo -en "\ec">&2;;
           --quiet )              verbose=;;
           --verbose )            verbose=t;;
           --debug )              debug=t; verbose=t;;
           --trace )              debug=t; verbose=t; trace=t; set -x;;

           --goggles-ip )         goggles_fn=goggles_ip;;

           --help )               usage; exit 1;;
           --help-full | --help-all | --help-extra )
                                  usage; usage_extra; exit 1;;
           * ) break;; esac; shift; done

        export goggles_fn remote_jq_opts

        dprint "main ARGV[], post option parsing: ${*@Q}"

        local default_op='bench-profile'
        local op="${1:-${default_op}}"; shift || true

        if test -z "$NIXOPS_DEPLOYMENT"
        then NIXOPS_DEPLOYMENT=$(basename $(pwd))
             oprint "NIXOPS_DEPLOYMENT:  $NIXOPS_DEPLOYMENT (defaulted)"
        else oprint "NIXOPS_DEPLOYMENT:  $NIXOPS_DEPLOYMENT (inherited)"
        fi
        export NIXOPS_DEPLOYMENT

        case "${op}" in
                init-params | init | reinit-params | reinit | analyse | a | analyse-run | arun | sanity-check | sanity | sanity-check-dir | sane-dir | srun | call | mass-analyse | mass ) true;;
                * ) params_check;; esac

        case "${op}" in
                init-params | init )  params_init "$@"
                                      list_profiles;;
                reinit-params | reinit )
                                      local node_count era topology
                                      node_count=$(parmetajq '.node_names | length')
                                      era=$(parmetajq '.era')
                                      topology=$(parmetajq '.topology')
                                      if test -z "$node_count"
                                      then fail "reinit:  cannot get node count from params file -- use init instead."; fi
                                      if test -z "$era"
                                      then fail "reinit:  cannot get era from params file -- use init instead."; fi
                                      params_init "$node_count" "$era" "$topology" "$@"
                                      list_profiles;;

                deploy )              profile_deploy "$@";;
                destroy )             deploystate_destroy;;

                genesis )             profile_genesis ${1:-$(params resolve-profile 'default')} 'keys' 'verbose';;
                genesis-info | gi )   genesis_info "$@";;
                profile-genesis-cache | pgc )
                                      prof=$(profgenjq "$1" .)
                                      cache_id=$(genesis_cache_id "$prof")
                                      dir=../geneses/$cache_id
                                      cat <<EOF
Profile $1
Genesis cache entry:  $(ls -d $dir 2>&1)
Genesis cache id:     $cache_id
Genesis cache key:
$(genesis_params_cache_params "$prof")
EOF
                                      ;;
                profile-genesis-cache-rehash | pgc-rehash )
                                      old_cache_id=$1
                                      dir=../geneses/$old_cache_id
                                      test -f "$dir/genesis-meta.json" ||
                                              fail "no genesis cache with id $old_cache_id: $dir"
                                      prof=$(jq .profile --raw-output $dir/genesis-meta.json)
                                      oprint "rehashing cache $old_cache_id for profile $prof"
                                      new_cache_id=$(genesis_cache_id "$(profgenjq "$prof" .)")
                                      genesis_params_cache_params "$(profgenjq "$prof" .)" > "$dir"/cache.params
                                      cat <<<$new_cache_id > "$dir"/cache.params.id
                                      mv "$dir" ../geneses/"$new_cache_id"
                                      ;;
                wait-for-empty-blocks | wait-empty | wait )
                                      op_wait_for_empty_blocks "$@";;
                stop )                op_stop "$@";;
                fetch | f )           op_stop
                                      fetch_tag "$@";;
                sanity-check | sanity | sane | check )
                                      export tagroot=$(realpath ./runs)
                                      sanity_check_tag "$@";;
                sanity-check-run | sanity-run | sane-run | check-run | srun )
                                      sanity_check_run "$@";;
                mark-tag-broken | mark-broken | broken )
                                      local tag dir
                                      tag=${1:-$(cluster_last_meta_tag)}
                                      dir="./runs/${tag}"
                                      mark_run_broken "$dir" "\"user-decision\"";;
                package | pkg )
                                      tagroot=$(realpath ./runs)
                                      resultroot=$(realpath ../bench-results)
                                      export tagroot resultroot
                                      package_tag "$@";;

                list-profiles | ps )  list_profiles;;
                query-profiles | query | qps | q )
                                      params query-profiles "${@:-.}" |
                                        words_to_lines | jq --raw-input |
                                        jq --slurp 'sort | .[]' -C;;
                show-profile | show | s )
                                      local prof=${1:-default}
                                      prof=$(params resolve-profile "$prof")
                                      profjq "$prof" '.';;

                profiles | profile | p )
                                      op_bench "$@";;
                profiles-jq | pjq )   local batch=$1 query=$2; shift 2
                                      op_bench "$batch" "jq($query)" "$@";;
                smoke-test | smoke )  local node=${1:-$(jq '.["cardano-node"].rev' nix/sources.bench.json --raw-output)}
                                      no_prebuild='true'
                                      op_bench 'smoke' "$node" 'smoke';;

                list-runs | runs | ls )
                                      ls -1 runs/*/meta.json | cut -d/ -f2;;
                archive-runs | archive )
                                      mkdir -p  'runs-archive'
                                      mv runs/* 'runs-archive';;

                split-bench-log | split )
                                      op_split_benchmarking_log "$@";;

                nodes | n )           op_nodes       "$@";;
                explorer | e )        op_on 'explorer'    "$@";;
                fetch-utxo | utxo )   op_fetch_utxo "$@";;

                jq-explorer | jqe )   op_jq 'explorer' "$@" | ${jq_select};;
                jq-generator | jqg )  op_jq_generator "$@" | ${jq_select};;
                jq-nodes | jqn )      op_jq_nodes    "$@" | ${jq_select};;

                pgrep )               nixops ssh-for-each --parallel -- pgrep -fal "$@";;
                grep )                local exp=${1?Usage:  grep EXPR}; shift
                                      nixops ssh-for-each --parallel -- grep "'$exp'" "/var/lib/cardano-node/logs/*" "$@";;
                md5sum | md5 | hash ) nixops ssh-for-each --parallel -- md5sum "$@";;
                time )                nixops ssh-for-each --parallel -- date +%s;;

                blocks )              op_blocks;;

                call )                "$@";;
                * ) usage; exit 1;; esac
}

###
### Top-level operations
###

op_bench() {
        local batch=${1:?Usage:  bench profile BATCH COMMITSPEC PROFILE..}
        local node_commitspec=${2:?Usage:  bench profile BATCH COMMITSPEC PROFILE..}
        local _prof=${3:?Usage:  bench profile BATCH COMMITSPEC PROFILE..}
        shift 2

        local benchmark_schedule
        if   case "$1" in jq\(*\) ) true;; * ) false;; esac
        then local query=$(sed 's_^jq(\(.*\))$_\1_' <<<$1)
             oprint "selecting profiles with:  $query"
             benchmark_schedule=($(query_profiles "$query"))
        elif test $# -eq 1
        then benchmark_schedule=("$1")
        else benchmark_schedule=("$@")
        fi

        if test ${#benchmark_schedule[*]} -gt 1
        then oprint "batch ${batch}:  benchmarking profiles:  ${benchmark_schedule[*]}"; fi

        for p in ${benchmark_schedule[*]}
        do bench_profile "$batch" "${p}" "$node_commitspec"
        done
}

bench_profile() {
        local batch=${1:?USAGE: bench_profile BATCH PROFSPEC NODE-COMMITSPEC}
        local profspec=${2:?USAGE: bench_profile BATCH PROFSPEC NODE-COMMITSPEC}
        local node_commitspec=${3:?USAGE: bench_profile BATCH PROFSPEC NODE-COMMITSPEC}
        local node_commit=$(if test "$node_commitspec" = 'pin'
                            then jq --raw-output '.["cardano-node"].rev' \
                                    nix/sources.bench.json
                            else cd ../cardano-node
                                 git fetch >/dev/null
                                 git rev-parse $node_commitspec
                            fi)
        test -n "$node_commit" ||
            fail "invalid cardano-node commitspec:  $node_commitspec"

        local node_commit_spec=$(if test "$node_commit" != "$node_commitspec"
                                 then echo "$node_commitspec"
                                 else (cd ../cardano-node
                                       git fetch >/dev/null
                                       git describe --all $node_commit)
                                 fi)
        local prof=$(params resolve-profile "$profspec")

        oprint "benchmarking profile:  ${prof:?Unknown profile $profspec, see ${paramsfile}}, batch $batch, node $node_commit ($node_commit_spec)"
        local deploylog='./last-deploy.log'

        local node_url="https://github.com/input-output-hk/cardano-node/archive/${node_commit}.tar.gz"
        local node_nixhash=$(nix-prefetch-url --unpack $node_url 2>/dev/null)
        local nodesrc=$(jq '.["cardano-node"]
                            | { rev:    $rev
                              , sha256: $sha256
                              , url:    $url
                              }' nix/sources.bench.json \
                          --arg rev    "$node_commit" \
                          --arg sha256 "$node_nixhash" \
                          --arg url    "$node_url")
        local args=(
            --attribute    rev=$node_commit
            --attribute sha256=$node_nixhash
            --attribute    url=$node_url
        )
        oprint_ne "niv:  "
        niv --sources-file nix/sources.bench.json 'modify' 'cardano-node' ${args[*]}

        if test -z "$no_deploy"
        then time profile_deploy "$batch" "$prof" "$nodesrc" "$node_commit_spec"
        else oprint "NOT deploying profile, due to --no-deploy!"
        fi

        op_bench_start "$batch" "$prof" "$deploylog" "$node_commit" "$node_commit_spec"
        ret=$?

        local tag dir
        tag=$(cluster_last_meta_tag)
        dir=$(realpath "./runs/$tag")

        if test $ret != 0
        then process_broken_run "$dir"
             return 1; fi

        oprint "$(date), termination condition satisfied, stopping cluster."
        op_stop
        time fetch_run "$dir"
        oprint "concluded run:  ${tag}"

        package_run "${dir}"
}

op_bench_start() {
        local batch=$1 prof=$2 deploylog=$3 node_commit=$4 node_commit_spec=$5 tag dir generator_startup_delay

        if ! params has-profile "${prof}"
        then fail "Unknown profile '${prof}': check ${paramsfile}"; fi

        test -f "${deploylog}" ||
                fail "deployment required, but no log found in:  ${deploylog}"

        oprint "stopping generator.."
        nixops ssh explorer "systemctl stop tx-generator || true"

        oprint "stopping nodes & journald.."
        op_stop

        oprint "resetting node states: node DBs & logs.."
        nixops ssh-for-each --parallel "rm -rf /var/log/journal/* /var/lib/cardano-node/{db*,logs,node-*,explorer,*.log,utxo}"

        oprint "$(date), restarting journald & nodes.."
        nixops ssh-for-each --parallel "systemctl start systemd-journald"
        sleep 3s
        nixops ssh-for-each --parallel "systemctl start cardano-node"

        local canary='node-0'
        node_wait_for_commit_id 'explorer' "$node_commit"
        node_wait_for_commit_id "$canary"  "$node_commit"

        ## Wait for genesis.systemStart to come.
        local now patience_start_pretty system_start
        now=$(date +%s)
        system_start=$(genesis_systemstart)
        if test "$(max $system_start $now)" != "$now"
        then oprint "waiting until cluster start time ($((system_start - now)) seconds).."
             while now=$(date +%s); test $now -lt $((system_start + 15))
             do sleep 1; done; fi

        tag=$(generate_run_tag "$batch" "$prof" "$node_commit")
        dir="./runs/${tag}"
        oprint "creating new run:  ${tag}"
        op_register_new_run "$batch" "$prof" "$tag" "$deploylog" "$node_commit_spec"

        oprint_ne "waiting until local node socket is up:  "
        while ! { nixops ssh explorer -- journalctl -u cardano-node |
                      grep "LocalHandshakeTrace\|LocalSocketUp" >/dev/null; }
        do sleep 1; echo -ne "."; done
        echo "LocalHandshakeTrace/LocalSocketUp seen"

        if nixops ssh "$canary" -- journalctl -u cardano-node |
           grep "TraceNoLedgerView" >/dev/null
        then fail "cluster is dead:  seen TraceNoLedgerView"; fi

        oprint_ne "sanity-checking cluster .systemStart:  "
        local genesis_systemStart=$(node_runtime_genesis_systemstart 'node-0')
        local logfile_systemStart=$(node_runtime_apparent_systemstart 'node-0')
        if test "$genesis_systemStart" = "$logfile_systemStart"
        then echo "genesis matches node log"
        else fail "systemStart mismatch: genesis=$genesis_systemStart, logfile=$logfile_systemStart"; fi

        time { oprint "$(date), starting generator.."
               nixops ssh explorer "systemctl start tx-generator"

               op_wait_for_nonempty_block "$prof" 200

               op_wait_for_empty_blocks "$prof" ""
               ret=$?
             }
        op_fetch_utxo

        return $ret
}

git_local_repo_query_description() {
        local name=$1 pin=$2

        test -d "../$name/.git" &&
        git -C "../$name/" fetch &&
        git -C "../$name/" describe --match '1.*' --tags $pin 2>/dev/null | cut -d- -f1,2 ||
        true
}

op_register_new_run() {
        local batch=$1 prof=$2 tag=$3 deploylog=$4 node_commit_spec=$5

        test -f "${deploylog}" ||
                fail "no deployment log found, but is required for registering a new benchmarking run."

        test -n "${tag}" || fail "cannot use an empty tag"

        local dir="./runs/${tag}"
        if test "$(realpath "${dir}")" = "$(realpath ./runs)" -o "${tag}" = '.'
        then fail "bad, bad tag"; fi

        rm -f                          ./last-run
        ln -s                 "${dir}" ./last-run
        rm -rf              ./"${dir}"/*
        mkdir -p              "${dir}"/{configs,logs}

        cp "${paramsfile}"   "${dir}"
        touch "$deployfile"
        cp "$deployfile" "${dir}"
        cat                 > "${dir}"/machines.json <<EOF
{$(cluster_machine_infos | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g')
}
EOF
        cp "${deploylog}"     "${dir}"/logs/deploy.log

        local sample_node=node-1
        oprint "streaming runtime genesis from $sample_node.."
        node_runtime_genesis $sample_node 'Shelley' > "$dir"/genesis-shelley.json &
        node_runtime_genesis $sample_node 'Alonzo'  > "$dir"/genesis-alonzo.json &
        ln -s                  'genesis-shelley.json' "$dir"/genesis.json

        oprint "recording effective service configs"
        for mach in $(params producers) 'explorer'
        do node_effective_service_config $mach 'cardano-node' \
              > "$dir"/configs/cardano-node.config.$mach.json &

           if test $mach = 'explorer'
           then node_effective_service_config $mach 'tx-generator' \
                 > "$dir"/configs/tx-generator.config.$mach.json & fi; done

        oprint "waiting for background transfers to settle.."
        time wait

        local date=$(date "+%Y-%m-%d-%H.%M.%S") stamp=$(date +%s)
        touch                 "${dir}/${date}"

        oprint "creating the initial run metafile"
        local        metafile="${dir}"/meta.json
        ln -sf    "${metafile}" last-meta.json
        jq      > "${metafile}" "
{ meta:
  { tag:               \"${tag}\"
  , batch:             \"${batch}\"
  , profile:           \"${prof}\"
  , timestamp:         ${stamp}
  , date:              \"${date}\"
  , node_commit_spec:  \"$node_commit_spec\"
  , node_commit_desc:  \"$(git_local_repo_query_description \
                              'cardano-node' \
                              $(depljq explorer '.pins["cardano-node"]' --raw-output))\"
  , pins:              $(depljq explorer  .pins)
  , genesis_cache_id:  \"$(genesis_cache_id "$(profgenjq "$prof" .)")\"
  , profile_content:   $(profjq "${prof}" .)
  , deployment_state:
    { explorer:  $(depljq explorer  .)
    , producers: $(depljq producers .)
    }
  }
, hostname:
  $(jq 'to_entries
   | map ({ key:   .key
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/machines.json)
, local_ip:
  $(jq  'to_entries
   | map ({ key:   .value.local_ip
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/machines.json)
, public_ip:
  $(jq  'to_entries
   | map ({ key:   .value.public_ip
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/machines.json)
}" --null-input

        oprint "recording the network latency matrix.."
        ./bench/latency-map.sh "$metafile" > "$dir"/network-latency-matrix.json
}

op_wait_for_nonempty_block() {
        local prof=$1 now since patience_start patience=400 patience_until now r
        now=$(date +%s)
        since=$now
        patience_start=$(max "$(genesis_systemstart)" $now)
        patience_start_pretty=$(date --utc --date=@$patience_start --iso-8601=s)
        patience_until=$((patience_start + patience))

        echo -n "--( waiting for a non-empty block on explorer (patience until $patience_start_pretty + ${patience}s).  Seen empty: 00"
        while now=$(date +%s); test "${now}" -lt ${patience_until}
        do r=$(nixops ssh explorer -- sh -c "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | head -n 20 | jq --compact-output \"select(.data.msg.\\\"txIds\\\" != [])\" | wc -l'")
           if test "$r" -ne 0
           then l=$(nixops ssh explorer -- sh -c "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | head -n 20 | jq \".data.msg.\\\"txIds\\\" | select(. != []) | length\" | jq . --slurp --compact-output'")
                echo ", got $l, after $((now - since)) seconds"
                return 0; fi
           e=$(nixops ssh explorer -- sh -c \
                   "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | head -n 20 | jq --slurp \"map (.data.msg.\\\"txIds\\\" | select(. == [])) | length\"'")
           echo -ne "\b\b"; printf "%02d" "$e"
           sleep 5; done

        touch "last-run/logs/block-arrivals.gauge"
        echo " patience ran out, stopping the cluster and collecting logs from the botched run."
        process_broken_run "runs/$tag"
        errprint "No non-empty blocks reached the explorer in ${patience} seconds -- is the cluster dead (genesis mismatch?)?"
}

op_wait_for_empty_blocks() {
        local prof=$1 slot_length=20
        local oneshot_action=${2:-true}

        local full_patience patience anyblock_patience
        full_patience=$(profjq "$prof" .tolerances.finish_patience)
        patience=$full_patience
        anyblock_patience=$full_patience

        echo -n "--( waiting for ${full_patience} empty blocks (txcounts): "
        local last_blkid='absolut4ly_n=wher'
        local news=
        while test $patience -gt 1 -a $anyblock_patience -gt 1
        do while news=$(nixops ssh explorer -- sh -c "'set -euo pipefail; { echo \"{ data: { msg: { blkid: 0, txIds: [] }}}\"; tac /var/lib/cardano-node/logs/node.json; } | grep -F MsgBlock | jq --compact-output \".data.msg | { blkid: (.blockHash | ltrimstr(\\\"\\\\\\\"\\\") | rtrimstr(\\\"\\\\\\\"\\\")), tx_count: (.txIds | length) } \"'" |
                        sed -n '0,/'$last_blkid'/ p' |
                        head -n-1 |
                        jq --slurp 'reverse | ## undo order inversion..
                          { txcounts: map (.tx_count)
                          , blks_txs: map ("\(.tx_count):\(.blkid)")
                          , last_blkid: (.[-1] // { blkid: $blkid}
                                        | .blkid)
                          }
                          ' --arg blkid ${last_blkid})
                 last_blkid=$(jq --raw-output .last_blkid <<<$news)
                 if test -n "${oneshot_action}"
                 then $oneshot_action; oneshot_action=; fi
                 echo -n " "
                 if test -z "${verbose}"
                 then jq -cj '.txcounts'
                 else echo -n "p${patience}"
                      jq -cj '.blks_txs | join(",") | "["+.+"]"'
                 fi <<<$news
                 ## A reasonable delay to see a new block.
                 sleep $slot_length
                 jqtest '.txcounts
                        | length == 0
                          or (all (. == 0) | not)' <<<$news &&
                 test "$anyblock_patience" -gt 1
           do if jqtest '.txcounts | length != 0' <<<$news
              then patience=${full_patience}
                   anyblock_patience=${full_patience}
                   test -z "${verbose}" || echo -n "=${patience}"
              else anyblock_patience=$((anyblock_patience - 1)); fi; done
           patience=$((patience - 1))
           test -z "${verbose}" || echo -n "p${patience}a${anyblock_patience}t$(jq .txcounts <<<$news)"
        done | tee "last-run/logs/block-arrivals.gauge"
        echo

        vprint "test termination:  patience=$patience.  anyblock_patience=$anyblock_patience"
        if test "$anyblock_patience" -le 1
        then errprint "No blocks reached the explorer in ${full_patience} seconds -- has the cluster died?"
             return 1; fi
}

fetch_logs() {
        local dir=${1:-.} tag components
        tag=$(run_tag "$dir")

        mkdir -p "$dir"/compressed

        local producers
        producers=($(params producers))
        oprint "fetching logs from:  explorer ${producers[*]}"

        oprint_ne "..done for: "
        for mach in 'explorer' ${producers[*]}
        do nixops ssh "${mach}" -- \
             "cd /var/lib/cardano-node &&
              { find logs -type l | xargs rm -f; }          &&
              rm -f                      ${mach}            &&
              ln -sf logs                ${mach}            &&
              (test ! -f cardano-node.prof     ||
               mv cardano-node.prof      ${mach}.prof)      &&
              (test ! -f cardano-node.eventlog ||
               mv cardano-node.eventlog  ${mach}.eventlog)  &&
              (test ! -f cardano-node.gcstats  ||
               mv cardano-node.gcstats   ${mach}.gcstats)   &&
              (journalctl --boot 0 --quiet   -u tx-generator |
               head -n 100        > ${mach}.tx-generator.unit-startup.log &&
                 test \$(stat -c %s ${mach}.tx-generator.unit-startup.log) != 0 ||
                   rm -f            ${mach}.tx-generator.unit-startup.log) &&
              (journalctl --boot 0 --quiet -u cardano-node |
               head -n 100        > ${mach}.cardano-node.unit-startup.log) &&
              tar c --zstd --dereference \$(ls | grep '^db-\|^logs$' -v)
           " |
                tee "$dir"/compressed/logs-$mach.tar.zst |
                tar x --zstd -C "$dir" &&
                echo -n " $mach" >&2 &
        done
        wait && echo '.' >&2
}

fetch_utxo() {
    local tag=$1
    local node=${2:-explorer}
    local file='runs/'$tag/utxo.$node.$(date +%s).json

    if nixops ssh $node -- cardano-cli query utxo --cardano-mode --whole-utxo --testnet-magic 42 --out-file '/var/lib/cardano-node/utxo'
    then oprint "fetching UTxO from $node into $file.."
         nixops scp --from $node '/var/lib/cardano-node/utxo' "$file" ||
             oprint "failed to fetch UTxO from $node"
    else oprint "failed to query UTxO on $node"
    fi
}

fetch_ledger() {
    local tag=$1
    local node=${2:-explorer}
    local file='runs/'$tag/ledger.$node.$(date +%s).json

    if nixops ssh $node -- cardano-cli query utxo --cardano-mode --whole-utxo --testnet-magic 42 --out-file '/var/lib/cardano-node/utxo'
    then oprint "fetching UTxO from $node into $file.."
         nixops scp --from $node '/var/lib/cardano-node/utxo' "$file" ||
             oprint "failed to fetch UTxO from $node"
    else oprint "failed to query UTxO on $node"
    fi
}

fetch_run() {
        local dir=${1:-.} tag components
        tag=$(run_tag "$dir")

        oprint "run directory:  ${dir}"
        fetch_logs "$dir"
        oprint "logs collected from run:  ${tag}"
}

package_run() {
        local dir=${1:-.}
        local tag=$(run_tag "$dir")
        local rundir=./runs/$tag

        local dirgood=$(realpath ../bench-results-bad)
        local dirbad=$(realpath ../bench-results)
        mkdir -p "$dirgood" "$dirbad"
        if is_run_broken "$dir"
        then resultroot=$dir
        else resultroot=$dirbad; fi

        local package=${resultroot}/$tag.tar.zst

        oprint "Packaging $tag ($(ls -d $rundir)) as:  $package"
        tar -C 'runs' \
            --exclude '*.gz' --exclude '*.xz' --exclude '*.zst' \
            -cf "$package"  "$tag" --zstd
}

atexit()
{ git checkout-index --force nix/sources.bench.json
}
trap atexit EXIT

# Keep this at the very end, so bash read the entire file before execution starts.
main "$@"
