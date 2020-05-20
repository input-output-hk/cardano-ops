#!/usr/bin/env bash
# shellcheck disable=2155

remote_jq_opts=(--compact-output)

declare -A deployfilename deployfile
deployfilename=(
        [explorer]='deployment-explorer.json'
        [producers]='deployment-producers.json')
deployfile=(
        [explorer]=$(realpath "$(dirname "$0")/../${deployfilename[explorer]}")
        [producers]=$(realpath "$(dirname "$0")/../${deployfilename[producers]}"))

## Deployfile JQ
depljq() {
        local comp=$1 q=$2; shift 2
        jq "$q" "${deployfilename[$comp]}" "$@"
}

update_deployfiles() {
        local prof=$1 deploylog=$2 include=${3##--include }
        local date=$(date "+%Y-%m-%d-%H.%M.%S") stamp=$(date +%s)
        local nixops_meta machine_info cores files targets

        echo "--( collecting NixOps metadata.."
        nixops_meta=$(grep DEPLOYMENT_METADATA= "$deploylog" |
                              head -n1 | cut -d= -f2 | xargs jq .)
        cores=($(params producers))
        case "$include" in
                '' | "explorer ${cores[*]}" | "${cores[*]} explorer" )
                                files=(${deployfile[*]})
                                targets=(explorer ${cores[*]});;

                'explorer' )    files=(${deployfile[explorer]})
                                targets=(explorer);;

                "${cores[*]}" ) files=(${deployfile[producers]})
                                targets=(${cores[*]});;

                * ) fail "include didn't match: '$include'";; esac

        local targetlist
        targetlist=$(jq . --raw-input <<<"${targets[*]}" | jq 'split(" ")' -c)
        dprint "target list: $targetlist"

        echo "--( collecting live machine state.."
        machine_info=$(jq . <<<"{ $(deploystate_collect_machine_info | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g') }")
        jq >"${files[0]}" "
          { profile:           \"$prof\"
          , timestamp:         ${stamp}
          , date:              \"${date}\"
          , targets:           $targetlist
          , genesis_hash:      \"$(cat ./keys/GENHASH)\"
          , profile_content:   $(profjq "${prof}" .)
          , pins:
            { benchmarking:    $(jq '.["cardano-benchmarking"].rev' nix/sources.json)
            , node:            $(jq '.["cardano-node"].rev'         nix/sources.bench-txgen-simple.json)
            , \"db-sync\":     $(jq '.["cardano-db-sync"].rev'      nix/sources.bench-txgen-simple.json)
            , ops:             \"$(git rev-parse HEAD)\"
            }
          , ops_modified:      $(if git diff --quiet --exit-code
                                 then echo false; else echo true; fi)
          , machine_info:      $machine_info
          , nixops:            $nixops_meta
          }
          " --null-input
        if test ${#files[*]} -gt 1
        then cp -f "${files[0]}" "${files[1]}"; fi
        echo "--( updated deployment state:  ${files[*]}"
}

deploystate_node_process_genesis_startTime() {
        local core="${1:-node-0}"
        nixops ssh ${core} \
          jq .startTime $(nixops ssh ${core} \
                  jq .GenesisFile $(nixops ssh ${core} -- \
                          pgrep -al cardano-node |
                                  sed 's_.* --config \([^ ]*\) .*_\1_'))
}

deploystate_local_genesis_startTime() {
        genesisjq '.start_time'
}

deploystate_check_deployed_genesis_age() {
        if ! check_genesis_age "$(deploystate_node_process_genesis_startTime 'node-0')"
        then fail "genesis needs update"; fi
}

check_genesis_age() {
        # test $# = 3 || failusage "check-genesis-age HOST SLOTLEN K"
        local startTime=$1 slotlen="${2:-20}" k="${3:-2160}" now
        now=$(date +%s)
        local age_t=$((now - startTime))
        local age_slots=$((age_t / slotlen))
        local remaining=$((k * 2 - age_slots))
        cat <<EOF
---| Genesis:  .startTime=${startTime}  now=${now}  age=${age_t}s  slotlen=${slotlen}
---|           slot age=${age_slots}  k=${k}  remaining=${remaining}
EOF
        if   test "${age_slots}" -ge $((k * 2))
        then fprint "genesis is too old"
             return 1
        elif test "${age_slots}" -ge $((k * 38 / 20))
        then fprint "genesis is dangerously old, slots remaining: ${remaining}"
             return 1
        fi
}

nixops_deploy() {
        local prof=$1 include=$2 deploylog=$3
        local node_rev benchmarking_rev ops_rev ops_checkout_state

        benchmarking_rev=$(jq --raw-output '.["cardano-benchmarking"].rev' nix/sources.json)
        node_rev=$(jq --raw-output '.["cardano-node"].rev' nix/sources.bench-txgen-simple.json)
        ops_rev=$(git rev-parse HEAD)
        ops_branch=$(maybe_local_repo_branch . ${ops_rev})
        ops_checkout_state=$(git diff --quiet --exit-code || echo '(modified)')
        to=${include:-the entire cluster}

        cat <<EOF
--( Deploying profile ${prof} to:  ${to#--include }
--(   node:          ${node_rev}
--(   benchmarking:  ${benchmarking_rev}
--(   ops:           ${ops_rev} / ${ops_branch}  ${ops_checkout_state}
EOF
        local cmd=( nixops deploy
                    --max-concurrent-copy 50 --cores 0 -j 4
                    ${include:+--include $include}
                  )

        local watcher_pid=
        if test -n "${watch_deploy}"
        then oprint "nixops deploy log:"
             { sleep 0.3; tail -f "$deploylog"; } &
             watcher_pid=$!; fi

        ln -sf "$deploylog" 'last-deploy.log'
        if export BENCHMARKING_PROFILE=${prof}; ! "${cmd[@]}" \
                 >"$deploylog" 2>&1
        then echo "FATAL:  deployment failed, full log in ${deploylog}"
             if test -n "$watcher_pid"
             then kill "$watcher_pid" >/dev/null 2>&1 || true
             else echo -e "FATAL:  here are the last 200 lines:\n"
                  tail -n200 "$deploylog"; fi
             return 1
        fi >&2

        if test -n "$watcher_pid"
        then kill "$watcher_pid" >/dev/null 2>&1 || true; fi

        update_deployfiles "$prof" "$deploylog" "$include"
}

deploystate_collect_machine_info() {
        local cmd
        cmd=(
                eval echo
                '\"$(hostname)\": { \"local_ip\": \"$(ip addr show dev eth0 | sed -n "/^    inet / s_.*inet \([0-9\.]*\)/.*_\1_; T skip; p; :skip")\", \"public_ip\": \"$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)\", \"account\": $(curl --silent http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq .AccountId), \"placement\": $(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone | jq --raw-input), \"sgs\": $(curl --silent http://169.254.169.254/latest/meta-data/security-groups | jq --raw-input | jq --slurp), \"timestamp\": $(date +%s), \"timestamp_readable\": \"$(date)\" }'
        )
        nixops ssh-for-each --parallel -- "${cmd[@]@Q}" 2>&1 | cut -d'>' -f2-
}

nixopsfile_producers() {
        jq '.benchmarkingTopology.coreNodes
            | map(.name)
            | join(" ")' --raw-output "$@"
}

op_stop() {
        nixops ssh-for-each --parallel "systemctl stop cardano-node 2>/dev/null || true"
        nixops ssh explorer            "systemctl stop cardano-explorer-node cardano-db-sync 2>/dev/null || true"
        nixops ssh-for-each --parallel "systemctl stop systemd-journald 2>/dev/null || true"
}

op_on() {
        local on="$1"; shift
        nixops ssh "${on}" -- "${@}" 2>&1 |
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

op_jq() {
        local on="$1"; shift
        local final_jq_opts=(
                "${remote_jq_opts[@]}"
                "'${1:-.}'"
                "/var/lib/cardano-node/logs/*.json"
        )
        op_on "${on}" jq "${final_jq_opts[@]}" |
                jq --compact-output --slurp 'sort_by(.at) | .[]'
}

op_jq_generator() {
        local final_jq_opts=(
                "${remote_jq_opts[@]}"
                "'${1:-.}'"
                "/var/lib/cardano-node/logs/generato*.json"
        )
        if ! op_on 'explorer' ls '/var/lib/cardano-node/logs/generato*.json' >/dev/null
        then fail "no generator logs on explorer."; fi
        op_on 'explorer' jq "${final_jq_opts[@]}" |
                jq --compact-output --slurp 'sort_by(.at) | .[]'
}

op_blocks() {
        nixops ssh explorer 'jq --compact-output "select (.data.kind == \"Recv\" and .data.msg.kind == \"MsgBlock\") | .data.msg" /var/lib/cardano-node/logs/node-*.json'
}
