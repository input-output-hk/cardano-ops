#!/usr/bin/env bash
# shellcheck disable=2207,2155,1007,1090
set -euo pipefail

. "$(dirname "$0")"/lib.sh
. "$(dirname "$0")"/lib-deploy.sh
. "$(dirname "$0")"/lib-params.sh
. "$(dirname "$0")"/lib-profile.sh
. "$(dirname "$0")"/lib-benchrun.sh
. "$(dirname "$0")"/lib-analysis.sh
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
    --force-deploy        Force redeployment, event if benchmarking
                            a single profile.
    --force-genesis       Force genesis regeneration, event if not required
                            by profile settings and deployment state.
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
no_deploy=
force_deploy=
force_genesis=
watch_deploy=

generator_startup_delay=25

self=$(realpath "$0")

main() {
        local jq_select='cat'

        while test $# -ge 1
        do case "$1" in
           --fast-unsafe | --fu ) no_deploy=t;;
           --deploy | --force-deploy )
                                  force_deploy=t;;
           --genesis | --force-genesis )
                                  force_genesis=t;;
           --watch | --watch-deploy )
                                  watch_deploy=t;;
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

        case "${op}" in
                init-params | init | reinit-params | reinit ) true;;
                * ) params_check;; esac

        case "${op}" in
                init-params | init )  params_init "$@";;
                reinit-params | reinit )
                                      local node_count
                                      node_count=$(parmetajq '.node_names | length')
                                      if test -z "$node_count"
                                      then fail "reinit:  cannot get node count from params file -- use init instead."; fi
                                      params_init "$node_count" "$@";;
                recreate-cluster | recreate )
                                      params_recreate_cluster "$@";;

                deploy )              profile_deploy "$@";;
                update-deployfiles | update )
                                      update_deployfiles "$@";;
                destroy )             deploystate_destroy;;

                check-genesis-age | check-genesis | genesis-age | age )
                                      deploystate_check_deployed_genesis_age "$@";;
                genesis )             profile_genesis_byron "$@";;

                wait-for-empty-blocks | wait-empty | wait )
                                      op_wait_for_empty_blocks "$@";;
                stop )                op_stop "$@";;
                fetch | f )           op_stop
                                      op_bench_fetch "$@";;
                analyse | a )
                                      export tagroot=$(realpath ./runs)
                                      analyse_tag "$@";;
                mark-run-broken | mark-broken | broken )
                                      mark_run_broken "$@";;
                package | pkg )
                                      tagroot=$(realpath ./runs)
                                      resultroot=$(realpath ../bench-results)
                                      export tagroot resultroot
                                      package_tag "$@";;

                list-profiles | ps )  rparmjq 'del(.meta) | keys';;
                query-profiles | query | qps | q )
                                      params query-profiles "${@:-.}" |
                                        words_to_lines | jq --raw-input |
                                        jq --slurp 'sort | .[]' -C;;
                show-profile | show | s )
                                      local prof=${1:-default}
                                      prof=$(params resolve-profile "$prof")
                                      profjq "$prof" '.';;

                bench-all | all )     op_bench 'all';;
                bench-profile | profiles | profile | p )
                                      op_bench "$@";;
                profiles-jq | pjq )
                                      local q=$1; shift
                                      op_bench "jq($q)" "$@";;
                smoke-test | smoke )
                                      no_deploy=t
                                      op_bench 'smoke';;

                list-runs | runs | ls )
                                      ls -1 runs/*/meta.json | cut -d/ -f2;;
                archive-runs | archive )
                                      mkdir -p  'runs-archive'
                                      mv runs/* 'runs-archive';;

                split-bench-log | split )
                                      op_split_benchmarking_log "$@";;

                nodes | n )           op_nodes       "$@";;
                explorer | e )        op_on 'explorer'    "$@";;

                jq-explorer | jqe )   op_jq 'explorer' "$@" | ${jq_select};;
                jq-generator | jqg )  op_jq_generator "$@" | ${jq_select};;
                jq-nodes | jqn )      op_jq_nodes    "$@" | ${jq_select};;

                pgrep )               nixops ssh-for-each --parallel -- pgrep -fal "$@";;
                grep )                local exp=${1?Usage:  grep EXPR}; shift
                                      nixops ssh-for-each --parallel -- grep "'$exp'" "/var/lib/cardano-node/logs/*" "$@";;
                md5sum | md5 | hash ) nixops ssh-for-each --parallel -- md5sum "$@";;
                time )                nixops ssh-for-each --parallel -- date +%s;;

                blocks )              op_blocks;;

                eval )                eval "${@@Q}";;
                * ) usage; exit 1;; esac
}
trap atexit EXIT
trap atexit SIGHUP
trap atexit SIGINT
trap atexit SIGTERM
trap atexit SIGQUIT
atexit() {
        true # pkill -f   "tee ${batch_log}"
}

###
### Top-level operations
###

op_bench() {
        local benchmark_schedule

        if   test "$1" = 'all'
        then benchmark_schedule=($(params profiles))
        elif case "$1" in jq\(*\) ) true;; * ) false;; esac
        then local query=$(sed 's_^jq(\(.*\))$_\1_' <<<$1)
             oprint "selecting profiles with:  $query"
             benchmark_schedule=($(query_profiles "$query"))
        elif test $# -eq 1
        then benchmark_schedule=("$1")
        else benchmark_schedule=("$@")
        fi

        if test ${#benchmark_schedule[*]} -gt 1
        then oprint "benchmark across profiles:  ${benchmark_schedule[*]}"; fi

        for p in ${benchmark_schedule[*]}
        do bench_profile "${p}"
        done
}

bench_profile() {
        local profspec="${1:-default}" prof deploylog
        prof=$(params resolve-profile "$profspec")

        oprint "benchmarking profile:  ${prof:?Unknown profile $profspec, see ${paramsfile}}"
        deploylog='./last-deploy.log'
        if ! test -f "${deploylog}" -a -n "${no_deploy}"
        then profile_deploy "${prof}"; fi

        local tag
        if ! op_bench_start "${prof}" "${deploylog}"
        then tag=$(cluster_last_meta_tag)
             process_broken_run "$tag"
             return 1; fi
        tag=$(cluster_last_meta_tag)

        oprint "$(date), termination condition satisfied, stopping cluster."
        op_stop
        op_bench_fetch
        oprint "concluded run:  ${tag}"

        tagroot=$(realpath ./runs)
        resultroot=$(realpath ../bench-results)
        export tagroot resultroot
        local tag
        tag=$(cluster_last_meta_tag)
        analyse_tag "${tag}"
        package_tag "${tag}"
}

op_bench_start() {
        local prof="$1" deploylog="$2" tag dir

        if ! params has-profile "${prof}"
        then fail "Unknown profile '${prof}': check ${paramsfile}"; fi

        test -f "${deploylog}" ||
                fail "deployment required, but no log found in:  ${deploylog}"

        oprint "stopping generator.."
        nixops ssh explorer "systemctl stop tx-generator || true"

        oprint "stopping nodes & explorer.."
        op_stop

        oprint "cleaning explorer DB.."
        nixops ssh explorer -- sh -c "'PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer --command \"delete from tx_in *; delete from tx_out *; delete from tx *; delete from block; delete from slot_leader *; delete from epoch *; delete from meta *; delete from schema_version *;\"'"

        oprint "resetting node states: node DBs & logs.."
        nixops ssh-for-each --parallel "rm -rf /var/lib/cardano-node/db* /var/lib/cardano-node/logs/* /var/log/journal/*"

        oprint "$(date), restarting nodes.."
        nixops ssh-for-each --parallel "systemctl start systemd-journald"
        sleep 3s
        nixops ssh-for-each --parallel "systemctl start cardano-node"
        nixops ssh explorer "systemctl start cardano-explorer-node cardano-db-sync"

        deploystate_check_deployed_genesis_age

        oprint "waiting ${generator_startup_delay}s for the nodes to establish business.."
        sleep ${generator_startup_delay}

        tag=$(generate_run_id "${prof}")
        dir="./runs/${tag}"
        oprint "creating new run:  ${tag}"
        op_register_new_run "${prof}" "${tag}" "${deploylog}"

        time { oprint "$(date), starting generator.."
               nixops ssh explorer "systemctl start tx-generator"

               op_wait_for_nonempty_block 200

               op_wait_for_empty_blocks \
                 "$(profjq "${prof}" .run.finish_patience)" \
                 fetch_systemd_unit_startup_logs
               ret=$?
             }
        op_stop

        return $ret
}

fetch_systemd_unit_startup_logs() {
        local tag dir
        tag=$(cluster_last_meta_tag)
        dir="./runs/${tag}"

        pushd "${dir}" >/dev/null || return 1

        mkdir -p 'logs/startup/'
        nixops ssh explorer \
          "journalctl --boot 0 -u tx-generator | head -n 100" \
          > 'logs/startup/unit-startup-generator.log'
        nixops ssh explorer "journalctl --boot 0 -u cardano-node | head -n 100" \
          > 'logs/startup/unit-startup-explorer.log'
        nixops ssh explorer "journalctl --boot 0 -u cardano-db-sync | head -n 100" \
          > 'logs/startup/unit-startup-db-sync.log'

        for node in $(params producers)
        do nixops ssh "${node}" "journalctl --boot 0 -u cardano-node | head -n 100" \
             > "logs/startup/unit-startup-${node}.log"
        done

        popd >/dev/null
}

op_register_new_run() {
        local prof="$1" tag="$2" deploylog="$3"

        test -f "${deploylog}" ||
                fail "no deployment log found, but is required for registering a new benchmarking run."

        mkdir -p runs

        test -n "${tag}" || fail "cannot use an empty tag"

        local dir="./runs/${tag}"
        if test "$(realpath "${dir}")" = "$(realpath ./runs)" -o "${tag}" = '.'
        then fail "bad, bad tag"; fi

        rm -f                          ./last-run
        ln -s                 "${dir}" ./last-run
        rm -rf              ./"${dir}"/*
        mkdir -p              "${dir}/logs"
        mkdir -p              "${dir}/meta"

        cp "${paramsfile}"   "${dir}"
        touch "${deployfile[@]}"
        cp "${deployfile[@]}" "${dir}"
        cat                 > "${dir}"/meta/cluster.raw.json <<EOF
{$(deploystate_collect_machine_info | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g')
}
EOF
        cp "${deploylog}"     "${dir}"/logs/deploy.log
        mv "${deploylog}"     runs/"${tag}".deploy.log

        local date=$(date "+%Y-%m-%d-%H.%M.%S") stamp=$(date +%s)
        touch                 "${dir}/${date}"

        local nixops_meta
        nixops_meta=$(grep DEPLOYMENT_METADATA= runs/"${tag}".deploy.log |
                        head -n1 | cut -d= -f2)

        local        metafile="${dir}"/meta.json
        ln -sf    "${metafile}" last-meta.json
        jq      > "${metafile}" "
{ meta:
  { tag:               \"${tag}\"
  , profile:           \"${prof}\"
  , timestamp:         ${stamp}
  , date:              \"${date}\"
  , profile_content:   $(profjq "${prof}" .)
  , manifest:
    [ \"${date}\"
    , \"${paramsfilename}\"
    , \"${deployfilename[explorer]}\"
    , \"${deployfilename[producers]}\"
    , \"meta.json\"

    , \"meta/cluster.raw.json\"

    , \"logs/deploy.log\"
    , \"logs/block-arrivals.gauge\"
    , \"logs/db-analysis.log\"
    , \"logs/db-analysis.tar.xz\"
    , \"logs/logs-explorer.tar.xz\"
    , \"logs/logs-nodes.tar.xz\"

    , \"tools/*.sql\"
    , \"tools/*.sh\" ]
  }
, hostname:
  $(jq 'to_entries
   | map ({ key:   .key
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/meta/cluster.raw.json)
, local_ip:
  $(jq  'to_entries
   | map ({ key:   .value.local_ip
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/meta/cluster.raw.json)
, public_ip:
  $(jq  'to_entries
   | map ({ key:   .value.public_ip
          , value: (.value + { hostname: .key })
          })
   | from_entries' "${dir}"/meta/cluster.raw.json)
}" --null-input
}

op_wait_for_nonempty_block() {
        local patience="$1" date patience_until now r prev=0
        start=$(date +%s)
        patience_until=$((start + patience))

        echo -n "--( waiting for a non-empty block on explorer (patience for ${patience}s).  Seen empty: 00"
        while now=$(date +%s); test "${now}" -lt ${patience_until}
        do r=$(nixops ssh explorer -- sh -c "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | jq \"select(.data.msg.txids != [])\" | wc -l'")
           if test "$r" -ne 0
           then l=$(nixops ssh explorer -- sh -c \
                   "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | jq \".data.msg.txids | select(. != []) | length\"'")
                echo ", got [$l], after $((now - start)) seconds"
                return 0; fi
           e=$(nixops ssh explorer -- sh -c \
                   "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | jq --slurp \"map (.data.msg.txids | select(. == [])) | length\"'")
           echo -ne "\b\b"; printf "%02d" "$e"
           sleep 5; done

        echo " patience ran out, stopping the cluster and collecting logs from the botched run."
        process_broken_run "$tag"
        errprint "No non-empty blocks reached the explorer in ${patience} seconds -- is the cluster dead (genesis mismatch?)?"
}

op_wait_for_empty_blocks() {
        local slot_length=20
        local full_patience="$1"
        local oneshot_action="${2:-true}"
        local patience=$full_patience
        local anyblock_patience=$full_patience

        echo -n "--( waiting for ${full_patience} empty blocks (txcounts): "
        local last_blkid='absolut4ly_n=wher'
        local news=
        while test $patience -gt 1 -a $anyblock_patience -gt 1
        do while news=$(nixops ssh explorer -- sh -c "'set -euo pipefail; { echo \"{ data: { msg: { blkid: 0, txids: [] }}}\"; tac /var/lib/cardano-node/logs/node.json; } | grep -F MsgBlock | jq --compact-output \".data.msg | { blkid: .blkid, tx_count: (.txids | length) } \"'" |
                        sed -n '0,/'$last_blkid'/ p' |
                        head -n-1 |
                        jq --slurp 'reverse | ## undo order inversion..
                          { txcounts: map (.tx_count)
                          , blks_txs: map ("\(.tx_count):\(.blkid)")
                          , last_blkid: (.[-1] // { blkid: "'${last_blkid}'"}
                                        | .blkid)
                          }')
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
           test -z "${verbose}" || echo -n "p${patience}"
        done | tee "last-run/logs/block-arrivals.gauge"
        echo

        vprint "test termination:  patience=$patience.  anyblock_patience=$anyblock_patience"
        if test "$anyblock_patience" -le 1
        then errprint "No blocks reached the explorer in ${full_patience} seconds -- has the cluster died?"
             return 1; fi
}

op_bench_fetch() {
        local tag dir components
        tag=${1:-$(cluster_last_meta_tag)}
        dir="./runs/${tag}"

        oprint "run directory:  ${dir}"
        pushd "${dir}" >/dev/null || return 1

        run_fetch_benchmarking 'tools'

        oprint "fetching the SQL extraction from explorer.."
        components=($(ls tools/*.sql | cut -d/ -f2))
        cat >'tools/db-analyser.sh' <<EOF
        set -e
        tag="\$1"

        files=()
        for query in ${components[*]}
        do files+=(\${query} \${query}.txt \${query}.csv)

           PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer \
             --file \${query} > \${query}.csv --csv
           PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer \
             --file \${query} > \${query}.txt
        done

        tar=${tag}.db-analysis.tar.xz
        tar cf \${tar} "\${files[@]}" --xz
        rm -f ${components[*]/%/.csv} ${components[*]/%/.txt}
EOF
        tar c 'tools/db-analyser.sh' "${components[@]/#/tools\/}" |
                nixops ssh explorer -- tar x --strip-components='1'
        nixops ssh explorer -- sh -c "ls; chmod +x 'db-analyser.sh';
                                      ./db-analyser.sh ${tag}" > 'logs/db-analysis.log'
        nixops scp --from explorer "${tag}.db-analysis.tar.xz" 'logs/db-analysis.tar.xz'

        local producers
        producers=($(params producers))
        oprint "fetching logs from:  explorer ${producers[*]}"
        mkdir -p 'logs'
        cd       'logs'

        for mach in 'explorer' ${producers[*]}
        do nixops ssh "${mach}" -- \
             "cd /var/lib/cardano-node &&
              { find logs -type l | xargs rm -f; } &&
              rm -f logs-${mach} &&
              ln -sf logs logs-${mach} &&
              tar c --dereference --xz logs-${mach}
           " | tar x --xz; done

        oprint "repacking logs.."
        local explorer_extra_logs=(
                unit-startup-generator.log
                unit-startup-explorer.log
                unit-startup-db-sync.log
        )

        { find logs-explorer/ \
               ${explorer_extra_logs[*]/#/startup\/} \
               -type f || true
        } | xargs tar cf logs-explorer.tar.xz --xz --

        { find logs-node-*/ \
               startup/unit-startup-node-*.log \
               -type f || true
        } | xargs tar cf logs-nodes.tar.xz    --xz --

        rm -f -- logs-*/* startup/*
        rmdir -- logs-*/  startup/ || true

        popd >/dev/null

        oprint "logs collected from run:  ${tag}"
}

# Keep this at the very end, so bash read the entire file before execution starts.
main "$@"
