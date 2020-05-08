#!/usr/bin/env bash
set -euo pipefail

###
### TODO
###
##  1. Automate genesis using cardano-node's Nix code. Param details are key.
##  2. Refactor into a less ugly thing.
##  3. Debug why kill -9 on the tx-generator removes _node's_ socket.
##  4. Make tx-generator exit on completion.
##  5. Refactor into a less ugly thing.
##  6. Did I mention?  Refactor the ugly away.
##  7. TODOs in 'cardano-benchmarking'

usage() {
        cat >&2 <<EOF
USAGE:  $(basename "$0") OPTIONS.. OP OP-ARGS..

  Options:

    --deploy              Before further business, deploy the full cluster.
    --deploy-fast         Before further business, deploy just the explorer.
    --include HOST        Deploy only to this host.
    --select JQEXPR       JQ log commands:  subset entries with select(JQEXPR).
    --goggles-ip          Log commands:  Replace IP addresses with "HOST-name".
                            Requires 'setup-goggles' subcommand to be run first.

    --wait-nodes [SEC=${wait_nodes}] Delay between forging nodes and generator startups.
    --wait-txs   [SEC=${wait_txs}] Delay between forging nodes and generator startups.

    --cls
    --trace
    --help

  OP is one of:

    bench-start           Cycle explorer & all nodes, and start the generator.
    bench-results         Fetch & analyse logs from explorer.
    bench-simple          Same as 'bench-start' & 'bench-results'.
    split-log FILE        Decompose a logfile into a directory named FILE.trace

    start-generator       Start the 'tx-generator' systemd service on explorer.
    restart-node          Restart the explorer's 'cardano-node'.

    get-cluster-params-raw
                          Query nodes for volatile parameters, like IP addresses.
    fetch-cluster-params  Cache cluster volatile parameters in ./.cluster.json

    nodes CMD..           Run CMD either on forging nodes or the explorer.
    explorer CMD..

    jq-explorer [JQEXPR=.]
    jq-generator [JQEXPR=.]
    jq-nodes [JQEXPR=.]   Run JQ on the JSON logs of either forging nodes,
                            explorer+generator or just the generator.
                            Log entries are sorted by timestamp.

    pgrep STR..           Run 'pgrep -fal "STR.."' across the cluster.
    hash PATH..           Run 'md5sum PATH..' across the cluster & sort on hash.

    blocks                'MsgBlock' messages seen by the explorer, incl. TxIds.
EOF
}

goggles_fn='cat'
remote_jq_opts=(--compact-output)

## Default is to deploy the entire cluster:
cluster_member_list=(a b c explorer)
deploy_list=("${cluster_member_list[@]}")

local_jq_opts=()
wait_nodes=25
wait_txs=90
self="$(realpath "$0")"

main() {
        local deploy=
        local jq_select='cat'

        while test $# -ge 1
        do case "$1" in
           --deploy )             deploy=t;;
           --deploy-fast )        deploy=t; deploy_list=(explorer);;
           --include )            deploy_list=("$2"); shift;;
           --select )             jq_select="jq 'select ($2)'"; shift;;
           --goggles-ip )         goggles_fn=goggles_ip;;
           --wait-nodes )         wait_nodes="$2"; shift;;
           --wait-txs )           wait_txs="$2"; shift;;

           --cls )                echo -en "\ec">&2;;
           --quiet )              verbose=;;
           --verbose )            verbose=t;;
           --debug )              debug=t; verbose=t;;
           --trace )              debug=t; verbose=t; trace=t; set -x;;

           --help )               usage; exit 1;;
           * ) break;; esac; shift; done

        export goggles_fn remote_jq_opts local_jq_opts

        if test "${deploy_list[*]}" = "${cluster_member_list[*]}"
        then nixops_include=
        else nixops_include="--include ${deploy_list[*]}"
        fi
        if test -n "${deploy}"
        then echo "--( Deploying commit $(git rev-parse HEAD | cut -c-8) / $(git symbolic-ref --short HEAD) ($(if git diff --quiet --exit-code
                         then echo pristine
                         else echo modified
                         fi)) to ${deploy_list[*]}"
             nixops deploy --max-concurrent-copy 50 -j 4 ${nixops_include}; fi

        local default_op='bench-simple'
        local op="${1:-${default_op}}"; shift || true
        case "${op}" in
                bench-simple | bench | go )
                                      op_bench_simple "$@";;
                bench-start )         op_bench_start "$@";;
                bench-results | results | r )
                                      op_bench_results "$@";;
                split-log | split | s )
                                      op_split_log "$@";;

                start-generator )     op_start_generator "$@";;
                restart-node )        op_restart_node "$@";;

                get-cluster-params-raw | params-raw )
                                      op_get_cluster_params_raw;;
                fetch-cluster-params | params )
                                      op_fetch_cluster_params;;

                nodes | n )           op_nodes       "$@";;
                explorer | e )        op_explorer    "$@";;
                jq-nodes | jqn )      op_jq_nodes    "$@" | ${jq_select};;
                jq-explorer | jqe )   op_jq_explorer "$@" | ${jq_select};;
                jq-generator | jqg )  op_jq_generator "$@" | ${jq_select};;

                pgrep )               op_pgrep "$@";;
                md5sum | md5 | hash ) op_hash "$@";;

                blocks )              op_blocks;;

                ls-run )              op_ls_run;;
                eval )                eval "${@@Q}";;
                * ) usage; exit 1;; esac
}

fail() {
	echo -e "ERROR:  $1" >&2
	exit 1
}

op_start_generator() {
        nixops ssh explorer "ls /run/cardano-node; systemctl start tx-generator"
}

op_restart_node() {
        nixops ssh explorer "systemctl restart cardano-node"
}

op_ls_run() {
        nixops ssh explorer "ls /run/cardano-node"
}

op_get_cluster_params_raw() {
        local cmd=(
                eval echo
                '\"$(hostname)\": { \"local_ip\": \"$(ip addr show dev eth0 | sed -n "/^    inet / s_.*inet \([0-9\.]*\)/.*_\1_; T skip; p; :skip")\", \"public_ip\": \"$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)\", \"account\": $(curl --silent http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq .AccountId), \"placement\": $(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone | jq --raw-input), \"sgs\": $(curl --silent http://169.254.169.254/latest/meta-data/security-groups | jq --raw-input | jq --slurp) }'
        )
        nixops ssh-for-each --parallel -- "${cmd[@]@Q}" 2>&1 | cut -d'>' -f2-
}

op_fetch_cluster_params() {
        cat > .cluster.raw.json <<EOF
{$(op_get_cluster_params_raw | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g')
}
EOF
        cat > .cluster.json <<EOF
{ "hostname":
  $(jq 'to_entries
   | map ({ "key":   .key
          , "value": (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
, "local_ip":
  $(jq  'to_entries
   | map ({ "key":   .value.local_ip
          , "value": (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
, "public_ip":
  $(jq  'to_entries
   | map ({ "key":   .value.public_ip
          , "value": (.value + { "hostname": .key })
          })
   | from_entries' .cluster.raw.json)
}
EOF
}

goggles_ip() {
        sed "$(jq --raw-output '.
              | .local_ip  as $local_ip
              | .public_ip as $public_ip
              | ($local_ip  | map ("s_\(.local_ip  | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g")) +
                ($public_ip | map ("s_\(.public_ip | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g"))
              | join("; ")
              ' .cluster.json)"
}

goggles() {
        ${goggles_fn}
}
export -f goggles goggles_ip

op_explorer() {
        nixops ssh explorer -- "${@}" 2>&1 |
                goggles
}

op_nodes() {
        nixops ssh-for-each --parallel --include a b c -- "${@}" 2>&1 |
                cut -d'>' -f2- |
                goggles
}

op_jq_nodes() {
        local final_jq_opts=(
                "${remote_jq_opts[@]}"
                "'${1:-.}'"
                "/var/lib/cardano-node/logs/*.json"
        )
        op_nodes    jq "${final_jq_opts[@]}" |
                jq --compact-output --slurp 'sort_by(.at) | .[]'
}

op_jq_explorer() {
        local final_jq_opts=(
                "${remote_jq_opts[@]}"
                "'${1:-.}'"
                "/var/lib/cardano-node/logs/*.json"
        )
        op_explorer jq "${final_jq_opts[@]}" |
                jq --compact-output --slurp 'sort_by(.at) | .[]'
}

op_jq_generator() {
        local final_jq_opts=(
                "${remote_jq_opts[@]}"
                "'${1:-.}'"
                "/var/lib/cardano-node/logs/generato*.json"
        )
        if ! op_explorer ls '/var/lib/cardano-node/logs/generato*.json' >/dev/null
        then fail "no generator logs on explorer."; fi
        op_explorer jq "${final_jq_opts[@]}" |
                jq --compact-output --slurp 'sort_by(.at) | .[]'
}

op_pgrep() {
        nixops ssh-for-each -- pgrep -fal "'$*'" 2>&1 |
                cut -d'>' -f2- | cut -c2-
}

op_hash() {
        nixops ssh-for-each -- md5sum "$@" 2>&1 |
                sort -k2 -t' '
}

op_blocks() {
        nixops ssh explorer "jq --compact-output 'select (.data.kind == \"Recv\" and .data.msg.kind == \"MsgBlock\") | .data.msg' /var/lib/cardano-node/logs/*.json"
}

op_bench_simple() {
        op_bench_start
        echo "--( Waiting ${wait_txs}s (--wait-txs) for the transactions to propagate.."
        sleep ${wait_txs}s
        op_bench_results
}

op_bench_start() {
        echo "--( Stopping generator.."
        nixops ssh explorer "systemctl stop tx-generator"

        local SVCS_ALL=(systemd-journald cardano-node)
        local SVCS_EXPLORER=(cardano-explorer-node cardano-db-sync)
        echo "--( Stopping nodes & explorer.."
        nixops ssh-for-each --parallel "systemctl stop ${SVCS_ALL[*]} 2>/dev/null"
        nixops ssh explorer "systemctl stop ${SVCS_EXPLORER[*]} 2>/dev/null"

        echo "--( Cleaning explorer DB.."
        nixops ssh explorer -- sh -c "'PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer --command \"delete from tx_in *; delete from tx_out *; delete from tx *; delete from block; delete from slot_leader *; delete from epoch *; delete from meta *; delete from schema_version *;\"'"

        echo "--( Resetting node states: node DBs & logs.."
        nixops ssh-for-each --parallel "rm -rf /var/lib/cardano-node/db* /var/lib/cardano-node/logs/* /var/log/journal/*"

        echo "--( Restarting nodes.."
        nixops ssh-for-each --parallel "systemctl start ${SVCS_ALL[*]}"
        nixops ssh explorer "systemctl start ${SVCS_EXPLORER[*]} 2>/dev/null"

        echo "--( Waiting for the nodes to establish business.."
        sleep ${wait_nodes}s

        echo "--( Starting generator.."
        nixops ssh explorer "systemctl start tx-generator"
}

op_bench_results() {
        echo "--( Fetching cluster parameters.."
        op_fetch_cluster_params
        export goggles_fn=goggles_ip

        echo "--( Fetching results:  part 1, {forgers,explorer,generator,full-cluster}.json"
        op_jq_generator > generator.json
        op_jq_explorer  > explorer.json
        op_jq_nodes     > forgers.json
        jq  --slurpfile explorer explorer.json \
            --slurpfile forgers  forgers.json '
        $explorer + $forgers | sort_by(.at) | .[]
        ' --null-input --compact-output > full-cluster.json

        echo "--( Fetching results:  part 2, as tarball for analyser"
        nixops ssh explorer "cd /var/lib/cardano-node; tar cz logs/*.json > logs.tar.gz"
        rm -rf ./bench-last-run
        mkdir -p bench-last-run
        cd bench-last-run
        nixops scp --from explorer "/var/lib/cardano-node/logs.tar.gz" .
        tar xaf logs.tar.gz --strip-components='1'
        rm logs.tar.gz

        echo "--( Fetching analyser from 'cardano-benchmarking'.."
        local benchmarking="$(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.outPath" | tr -d '"' )"
        test -n "${benchmarking}" ||
                fail "couldn't fetch 'cardano-benchmarking'"
        cp -f "${benchmarking}"/scripts/{analyse,xsends,xrecvs}.sh .
        chmod +x {analyse,xsends,xrecvs}.sh
        ls -l

        echo "--( Running analyser.."
        ./analyse.sh ./generato ./nod
}

op_split_log() {
        local log="$1"
        local dir="${log/.json/.split}"

        test -f "${log}" -a "${log}" != "${dir}" -a -n "${dir}" ||
                fail "The log (${log}) file must exist, and must end with '.json'"

        mkdir -p "${dir}"
        rm -rf ./"${dir}"/*
        cd       "${dir}"
        set +e ## otherwise grep will trigger exit

        cat                      > stage00.json              < "../${log}"

        grep -v ' MsgSubmitTx '  > stage01.json              < stage00.json
        grep    ' MsgSubmitTx '  > e-fro-g.MsgSubmitTx.json  < stage00.json

        grep -v '"MsgRe\(quest\|ply\)Txs"\|"TraceTxSubmissionOutbound\(SendMsgReply\|RecvMsgRequest\)Txs"' \
                < stage01.json   > stage02.json
        grep    '"MsgRe\(quest\|ply\)Txs"\|"TraceTxSubmissionOutbound\(SendMsgReply\|RecvMsgRequest\)Txs"' \
                < stage01.json   > e-and-a.MsgRRTxs.TraceTxSubmissionOutboundSRMRRTxs.json

        grep -v '"TraceMempool\(AddedTx\|RemoveTxs\)"' \
                < stage02.json   > stage03.json
        grep    '"TraceMempool\(AddedTx\|RemoveTxs\)"' \
                < stage02.json   > e.TraceMempoolARTxs.json

        grep -v '"TraceBenchTxSubRecv"' \
                < stage03.json   > stage04.json
        grep    '"TraceBenchTxSubRecv"' \
                < stage03.json   > g-to-e.TraceBenchTxSubRecv.json

        ## Extra processing
        jq .data.message         < e-fro-g.MsgSubmitTx.json |
                sed 's_.*Recv MsgSubmitTx tx: Tx \([0-9a-f]*\) .*_\1_' |
                sort -u          > txs-init
        # grep -vFf txs-init       > noInitTxs.json      < orig.json

        cd ..
        for f in "${dir}"/*
        do wc -l "${f}"; done
}

# Keep this at the very end, so bash read the entire file before execution starts.
main "$@"
