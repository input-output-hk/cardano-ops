#!/usr/bin/env bash
# shellcheck disable=2155

deployfilename=(
        'deployment-explorer.json'
        'deployment-producers.json')
deployfile=(
        $(realpath "$(dirname "$0")/../${deployfilename[0]}")
        $(realpath "$(dirname "$0")/../${deployfilename[1]}"))

update_deployfiles() {
        local prof=$1 deploylog=$2 include=${3##--include } file
        local date=$(date "+%Y-%m-%d-%H.%M.%S") stamp=$(date +%s)
        local nixops_meta node_info full cores files targets

        echo "--( collecting NixOps metadata.."
        nixops_meta=$(grep DEPLOYMENT_METADATA= "$deploylog" |
                              head -n1 | cut -d= -f2 | xargs jq .)
        cores=($(nixopsfile_producers <<<$nixops_meta))
        case "$include" in
                '' | "explorer ${cores[*]}" | "${cores[*]} explorer" )
                                files=(${deployfile[*]}); targets=(explorer ${cores[*]});;
                'explorer' )    files=(${deployfile[0]}); targets=(explorer);;
                "${cores[*]}" ) files=(${deployfile[1]}); targets=(${cores[*]});;
                * ) fail "include didn't match: '$include'";; esac

        echo "--( collecting live machine state.."
        node_info=$(jq . <<<"{ $(nixops_query_cluster_state | sed ':b; N; s_\n_,_; b b' | sed 's_,_\n,_g') }")
        jq >"${files[0]}" "
          { profile:           \"$prof\"
          , timestamp:         ${stamp}
          , date:              \"${date}\"
          , targets:           $(jq . --raw-input <<<"${targets[*]}" | jq --slurp -c)
          , genesis_hash:      \"$(cat ./keys/GENHASH)\"
          , profile_content:   $(jq ."[\"${prof}\"]" "${clusterfile}" |
                                 sed 's_^_      _')
          , benchmarking:      $(jq '.["cardano-benchmarking"].rev' nix/sources.json)
          , node:              $(jq '.["cardano-node"].rev'         nix/sources.bench-txgen-simple.json)
          , \"db-sync\":       $(jq '.["cardano-db-sync"].rev'      nix/sources.bench-txgen-simple.json)
          , ops:               \"$(git rev-parse HEAD)\"
          , modified:          $(if git diff --quiet --exit-code
                                 then echo false; else echo true; fi)
          , node_info:         $node_info
          , nixops:            $nixops_meta
          }
          " --null-input
        if test ${#files[*]} -gt 1
        then cp -f "${files[0]}" "${files[1]}"; fi
        echo "--( updated deployment state:  ${files[*]}"
}

nixopsfile_producers() {
        jq '.benchmarkingTopology.coreNodes
            | map(.name)
            | join(" ")' --raw-output "$@"
}

remote_jq_opts=(--compact-output)

nixops_query_cluster_state() {
        local cmd
        cmd=(
                eval echo
                '\"$(hostname)\": { \"local_ip\": \"$(ip addr show dev eth0 | sed -n "/^    inet / s_.*inet \([0-9\.]*\)/.*_\1_; T skip; p; :skip")\", \"public_ip\": \"$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)\", \"account\": $(curl --silent http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq .AccountId), \"placement\": $(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone | jq --raw-input), \"sgs\": $(curl --silent http://169.254.169.254/latest/meta-data/security-groups | jq --raw-input | jq --slurp), \"timestamp\": $(date +%s), \"timestamp_readable\": \"$(date)\" }'
        )
        nixops ssh-for-each --parallel -- "${cmd[@]@Q}" 2>&1 | cut -d'>' -f2-
}

maybe_local_repo_branch() {
        local local_repo_path=$1 rev=$2
        git -C "$local_repo_path" describe --all "$rev" |
                sed 's_^\(.*/\|\)\([^/]*\)$_\2_'
        ## This needs a shallow clone to be practical.
}

nixops_deploy() {
        local prof="${1:-default}" include="${2:-}" deploylog="${3:-}"
        local node_rev benchmarking_rev ops_rev ops_checkout_state
        if test -z "${include}${deploylog}"
        then deploylog=runs/$(date +%s).full-deploy; fi

        benchmarking_rev=$(jq --raw-output '.["cardano-benchmarking"].rev' nix/sources.json)
        node_rev=$(jq --raw-output '.["cardano-node"].rev' nix/sources.bench-txgen-simple.json)
        ops_rev=$(git rev-parse HEAD)
        ops_branch=$(maybe_local_repo_branch . ${ops_rev})
        ops_checkout_state=$(git diff --quiet --exit-code || echo '(modified)')
        prof=$(cluster_sh resolve-profile "${prof}")
        to=${include:-the entire cluster}

        cat <<EOF
--( Deploying to:  ${to#--include }
--(   node:          ${node_rev}
--(   benchmarking:  ${benchmarking_rev}
--(   ops:           ${ops_rev} / ${ops_branch}  ${ops_checkout_state}
EOF
        ln -sf "$deploylog" 'last-deploy.log'
        if export BENCHMARKING_PROFILE=${prof}; ! nixops deploy --max-concurrent-copy 50 -j 4 ${include} \
                 >"$deploylog" 2>&1
        then echo "FATAL:  deployment failed, full log in ${deploylog}"
             echo -e "FATAL:  here are the last 200 lines:\n"
             tail -n200 "$deploylog"
             return 1
        fi >&2

        update_deployfiles "$prof" "$deploylog" "$include"
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
