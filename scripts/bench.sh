#!/usr/bin/env bash
# shellcheck disable=2207,2155,1007,1090
set -euo pipefail

clusterfile=
. "$(dirname "$0")"/lib.sh
. "$(dirname "$0")"/lib-nixops.sh
. "$(dirname "$0")"/lib-cardano.sh
. "$(dirname "$0")"/lib-cluster.sh
. "$(dirname "$0")"/lib-benchrun.sh
###
### TODO
###
##  1. Automate genesis using cardano-node's Nix code. Param details are key.
##  2. Debug why kill -9 on the tx-generator removes _node's_ socket.
##  3. Make tx-generator exit on completion.
##  4. TODOs in 'cardano-benchmarking'

usage() {
        cat >&2 <<EOF
USAGE:  $(basename "$0") OPTIONS.. OP OP-ARGS..

  Options:

    --fast-unsafe         Ignore safety, go fast.  Deploys won't be made,
                            unprocessed logs will be lost.

    --cls                 Clear screen.
    --trace               set -x
    --help                ...

  OP is one of:

    init-cluster N        Make a default ${clusterfile}
                            for a cluster with N nodes.

    check-genesis-age NODE SLOTLEN K
                          Test genesis of a deployed NODE, given SLOTLEN and K.

    bench                 Run benchmark across all profiles in ${clusterfile}.
    bench-profile         Run benchmark for a single profile.

    bench-start           Cycle explorer & all nodes, and start the generator.
    bench-fetch           Fetch cluster logs.
    bench-analyse         Analyse cluster logs & prepare results.
    bench-losses          Analyse Tx losses (use inside a bench run dir).
    bench-results         Same as bench-fetch/-analyse.

    stop                  Stop the cluster, including all journald instances.

    list-runs | ls        List accumulated benchmark runs.

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
EOF
}

no_deploy_producers=
no_deploy_explorer=
clobber_deploy_logs=

## If a freshly-restarted cluster with valid genesis allows the explorer to see
## no blocks, for this long -- something must be wrong.
cluster_improductivity_patience=60

self=$(realpath "$0")

main() {
        local jq_select='cat'

        while test $# -ge 1
        do case "$1" in
           --fast-unsafe | --fu )
                   no_deploy_producers=t
                   no_deploy_explorer=t
                   clobber_deploy_logs=t;;
           --select )             jq_select="jq 'select ($2)'"; shift;;

           --cls )                echo -en "\ec">&2;;
           --quiet )              verbose=;;
           --verbose )            verbose=t;;
           --debug )              debug=t; verbose=t;;
           --trace )              debug=t; verbose=t; trace=t; set -x;;

           --goggles-ip )         goggles_fn=goggles_ip;;

           --help )               usage; exit 1;;
           * ) break;; esac; shift; done

        export goggles_fn remote_jq_opts

        local default_op='bench'
        local op="${1:-${default_op}}"; shift || true

        case "${op}" in
                init-cluster | init ) true;;
                * ) clusterfile_init;; esac

        case "${op}" in
                init-cluster | init )
                                      op_init_cluster "$@";;
                check-genesis-age | check-genesis | genesis-age | age )
                                      op_check_genesis_age "$@";;

                deploy-cluster | full-deploy | deploy )
                                      nixops_deploy "" \
                                        "runs/$(date +%s).full-deploy";;
                bench-start | start )
                                      op_bench_start "$@";;
                bench-fetch | fetch | f )
                                      op_bench_fetch "$@";;
                bench-analyse | analyse | a )
                                      op_bench_analyse "$@";;
                bench-results | results | r )
                                      op_bench_fetch
                                      op_bench_analyse "$@";;
                bench-losses | losses | lost | l )
                                      op_analyse_losses "$@";;

                bench-profile | profile | p )
                                      op_bench_profile "$@";;

                bench | all )
                                      op_bench "$@";;

                list-runs | runs | ls )
                                      ls -1 runs/*.json |
                                      sed 's_^runs/\(.*\).json$'_\\1_;;

                wait-for-empty-blocks | wait-empty | wait )
                                      op_wait_for_empty_blocks "$@";;
                stop )                op_stop "$@";;

                split-bench-log | split )
                                      op_split_benchmarking_log "$@";;

                nodes | n )           op_nodes       "$@";;
                explorer | e )        op_on 'explorer'    "$@";;

                jq-explorer | jqe )   op_jq 'explorer' "$@" | ${jq_select};;
                jq-generator | jqg )  op_jq_generator "$@" | ${jq_select};;
                jq-nodes | jqn )      op_jq_nodes    "$@" | ${jq_select};;

                pgrep )               op_pgrep "$@";;
                md5sum | md5 | hash ) op_hash "$@";;

                blocks )              op_blocks;;

                eval )                eval "${@@Q}";;
                * ) usage; exit 1;; esac
}

###
### Top-level operations
###

op_bench() {
        local all_profiles=($(cluster_sh profiles))
        local benchmark_schedule=("${all_profiles[@]}")

        echo "--( Benchmark across profiles:  ${benchmark_schedule[*]}"

        mkdir -p 'runs'

        if test -n "${no_deploy_producers}"
        then echo "--( Not deploying producers, --no-deploy-producers passed."
        else nixops_deploy "--include $(cluster_sh producers)" \
               "runs/$(date +%s).deploy-producers.log"; fi

        clobber_deploy_logs=t ## Allow the full runs to proceed regardless.
        for p in ${benchmark_schedule[*]}
        do op_bench_profile "${p}"
        done
}

op_bench_profile() {
        local spec="${1:-default}"
        local prof=$(cluster_sh resolve-profile "$spec")
        local deploylog='./last-explorer-deploy.log'

        echo "--( Benchmarking profile ${prof:?Unknown profile $spec, see ${clusterfile}}.."
        if ! test -f "${deploylog}" -a -n "${no_deploy_explorer}"
        then nixops_deploy '--include explorer' "${deploylog}"; fi
        op_bench_start "${prof}" "${deploylog}"
        op_bench_fetch
        op_bench_analyse
}

op_bench_start() {
        local prof="$1" deploylog="$2"

        if ! cluster_sh has-profile "${prof}"
        then fail "Unknown profile '${prof}': check ${clusterfile}"; fi

        test -f "${deploylog}" ||
                fail "deployment required, but no log found in:  ${deploylog}"

        echo "--( Stopping generator.."
        nixops ssh explorer "systemctl stop tx-generator || true"

        echo "--( Stopping nodes & explorer.."
        op_stop

        echo "--( Cleaning explorer DB.."
        nixops ssh explorer -- sh -c "'PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer --command \"delete from tx_in *; delete from tx_out *; delete from tx *; delete from block; delete from slot_leader *; delete from epoch *; delete from meta *; delete from schema_version *;\"'"

        echo "--( Resetting node states: node DBs & logs.."
        nixops ssh-for-each --parallel "rm -rf /var/lib/cardano-node/db* /var/lib/cardano-node/logs/* /var/log/journal/*"

        echo "--( $(date), restarting nodes.."
        nixops ssh-for-each --parallel "systemctl start systemd-journald"
        sleep 3s
        nixops ssh-for-each --parallel "systemctl start cardano-node"
        nixops ssh explorer "systemctl start cardano-explorer-node cardano-db-sync 2>/dev/null"

        op_check_genesis_age

        op_wait_for_any_blocks

        local tag=$(generate_run_id "${prof}")
        echo "--( creating new run:  ${tag}"
        op_register_new_run "${prof}" "${tag}" "${deploylog}"

        echo "--( $(date), starting generator.."
        nixops ssh explorer "systemctl start tx-generator"

        op_wait_for_empty_blocks 4

        echo "--( $(date), termination criteria satisfied, stopping cluster."
        op_stop
}

op_register_new_run() {
        local prof="$1" tag="$2" deploylog="$3"

        test -f "${deploylog}" ||
                fail "no deployment log found, but is required for registering a new benchmarking run."

        mkdir -p runs

        mv "${deploylog}" runs/"${tag}".deploy.log
        local nixops_meta=$(grep DEPLOYMENT_METADATA= runs/"${tag}".deploy.log |
                                    head -n1 | cut -d= -f2)

        local date=$(date) stamp=$(date +%s)
        ln -sf runs/"${tag}".json       last-run.json

        cat > .cluster.raw.json <<EOF
{$(nixops_query_cluster_state | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g')
}
EOF
        jq . > runs/"${tag}".json <<EOF
{ "meta": {
    "timestamp": ${stamp},
    "date": "${date}",
    "node": $(jq '.["cardano-node"].rev' nix/sources.json),
    "db-sync": $(jq '.["cardano-db-sync"].rev' nix/sources.json),
    "tag": "${tag}",
    "profile": "${prof}",
    "generator_params": $(jq ."[\"${prof}\"]" "${clusterfile}" |
                          sed 's_^_      _'),
    "ops": "$(git rev-parse HEAD)",
    "modified": $(if git diff --quiet --exit-code
                  then echo false; else echo true; fi)
  }
, "nixops_metafile": "${nixops_meta}"
, "nixops": $(jq . "${nixops_meta}")
, "hostname":
  $(jq 'to_entries
   | map ({ key:   .key
          , value: (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
, "local_ip":
  $(jq  'to_entries
   | map ({ key:   .value.local_ip
          , value: (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
, "public_ip":
  $(jq  'to_entries
   | map ({ key:   .value.public_ip
          , value: (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
}
EOF
}

op_wait_for_any_blocks() {
        local start=$(date +%s)
        local patience_until=$((start + cluster_improductivity_patience))
        local now=

        echo -n "--( Waiting for blocks to appear on explorer (patience for ${cluster_improductivity_patience}s): "
        while now=$(date +%s); test "${now}" -lt ${patience_until}
        do local r=$(nixops ssh explorer -- sh -c "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | head -n1 | wc -l'")
           if test "$r" -ne 0
           then echo "$r block(s) appeared after $((now - start)) seconds"
                return 0; fi
           sleep 1; done
        echo "none."
        fail "\nno blocks reached the explorer in ${cluster_improductivity_patience} seconds -- is cluster dead?"
}

op_wait_for_empty_blocks() {
        local slot_length=20
        local block_propagation_tolerance=1
        local full_patience="${1:-4}"
        local patience=${full_patience}

        echo -n "--( Waiting for empty blocks (txcounts): "
        local last_blk='0000000000'
        while test ${patience} -gt 0
        do local news=
           while news=$(nixops ssh explorer -- sh -c "'tac /var/lib/cardano-node/logs/node.json | grep -F MsgBlock | jq --compact-output \".data.msg | { blkid: .blkid, tx_count: (.txids | length) } \"'" |
                        sed -n '0,/'${last_blk}'/ p' |
                        if test "${last_blk}" = '0000000000'
                        then cat; else head -n-1; fi |
                        jq --slurp 'reverse | ## undo order inversion..
                          { blks_txs: map (.tx_count)
                          , last_blk: (.[-1] // { blkid: "'${last_blk}'"}
                                      | .blkid)
                          }')
                 echo -n " "
                 ## A reasonable delay to see a new block.
                 sleep $((slot_length + block_propagation_tolerance))
                 jqtest '.blks_txs
                        | length == 0
                        or (all (. == 0) | not)' <<<${news}
           do patience=${full_patience}
              jq -cj '.blks_txs' <<<${news}
              last_blk=$(jq --raw-output .last_blk <<<${news}); done
           echo -n '[0]'
           patience=$((patience - 1))
        done
        echo
}

op_bench_fetch() {
        # echo "--( Fetching results:  part 1, {explorer,generator}.json"
        # op_jq_generator   > generator.json
        # op_jq 'explorer'  > explorer.json
        # op_jq 'a'         > node-a.json
        # op_jq_nodes     > forgers.json
        # jq  --slurpfile explorer explorer.json \
        #     --slurpfile forgers  forgers.json '
        # $explorer + $forgers | sort_by(.at) | .[]
        # ' --null-input --compact-output > full-cluster.json

        local meta=./last-run.json
        jq . "${meta}" >/dev/null || fail "invalid run metadata: ${meta}"

        local tag=$(jq --raw-output .meta.tag "${meta}")
        if test -z "${tag}"
        then fail "cannot determine tag for last run"; fi
        local dir="./runs/${tag}"
        if test "$(realpath "${dir}")" = "$(realpath ./runs)"
        then fail "bad, bad tag"; fi
        deploylog="./runs/${tag}.deploy.log"
        test -f "${deploylog}" ||
                fail "deployment required, but no log found in:  ${deploylog}"

        rm -f                        ./runs-last
        ln -s               "${dir}" ./runs-last
        rm -rf            ./"${dir}"/*
        mkdir -p            "${dir}/logs"
        cp "${clusterfile}" "${dir}"
        cp "${meta}"        "${dir}"/profile-run-metadata.json
        cp "${deploylog}"   "${dir}"/logs/deploy.log
        pushd               "${dir}" >/dev/null
        touch "$(jq --raw-output .meta.date ./profile-run-metadata.json)"

        echo "--( Run directory:  ${dir}"

        echo "--( Fetching tools from 'cardano-benchmarking' $(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.rev" | tr -d '"' | cut -c-8) .."
        local benchmarking=$(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.outPath" | tr -d '"' )
        test -n "${benchmarking}" ||
                fail "couldn't fetch 'cardano-benchmarking'"
        mkdir -p 'tools'
        cp -a "${benchmarking}"/scripts/*.{sh,sql} 'tools'

        echo "--( Fetching the SQL extraction from explorer.."
        local components=($(ls tools/*.sql | cut -d/ -f2))
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

        echo "--( Fetching logs:  explorer"
        mkdir -p 'logs'
        while ! nixops ssh explorer "cd /var/lib/cardano-node; rm -f logs-${tag}.tar.xz; tar cf logs-${tag}.tar.xz --xz logs/*.json"
        do echo "retrying log packing in 20s.."; sleep 20; done
        nixops scp --from explorer "/var/lib/cardano-node/logs-${tag}.tar.xz" \
          'logs/logs-explorer-generator.tar.xz'

        echo "--( Fetching logs:  producers"
        while ! nixops ssh-for-each --parallel \
                --include $(cluster_sh producers) \
                -- "cd /var/lib/cardano-node; rm -f logs-${tag}.tar.xz; tar cf node-\${HOSTNAME}-logs-${tag}.tar.xz --xz logs/*.json"
        do echo "retrying log packing in 20s.."; sleep 20s; done

        for node in $(cluster_sh producers)
        do nixops scp --from "${node}" \
             "/var/lib/cardano-node/node-${node}-logs-${tag}.tar.xz" \
             "logs/logs-node-${node}.tar.xz"
        done

        popd >/dev/null
}

op_bench_analyse() {
        echo "--( cardano-ops rev $(git rev-parse HEAD | cut -c-8)"

        local meta=./last-run.json
        jq . "${meta}" >/dev/null || fail "invalid run metadata: ${meta}"

        local tag=$(jq --raw-output .meta.tag "${meta}")
        if test -z "${tag}"
        then fail "cannot determine tag for last run"; fi
        local dir="./runs/${tag}"
        if test "$(realpath "${dir}")" = "$(realpath ./runs)" -a -d "${dir}"
        then fail "bad, bad tag"; fi

        pushd "${dir}" >/dev/null || return 1
        rm -rf 'analysis'
        mkdir  'analysis'
        cd     'analysis'

        echo "--( Consolidating explorer logs.."
        tar xaf '../logs/logs-explorer-generator.tar.xz' --strip-components='1'
        if test -L node.json
        then rm node.json
             cat node-[0-9]*.json > node-explorer.json
             rm -f node-[0-9]*.json
        fi

        echo "--( Running log analysis.."
        ls -l
        ../tools/analyse.sh generator node "run-last/analysis"
        cp analysis/{timetoblock.csv,tx-stats.json} .

        tar xaf '../logs/db-analysis.tar.xz' --wildcards '*.csv' '*.txt'

        if jqtest '(.tx_missing != 0)' tx-stats.json
        then echo "--( Losses found, analysing.."
             op_analyse_losses
        fi
        popd >/dev/null
}

# Keep this at the very end, so bash read the entire file before execution starts.
main "$@"
