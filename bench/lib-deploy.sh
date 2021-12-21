#!/usr/bin/env bash
# shellcheck disable=2155

remote_jq_opts=(--compact-output)

declare -A deployfilename deployfile
deployfilename='deployment.json'
deployfile=$(realpath "$(dirname "$0")/../$deployfilename")

## Deployfile JQ
depljq() {
        local comp=$1 q=$2; shift 2
        jq "$q" "$deployfilename" "$@"
}

update_deployfile() {
        local prof=$1 deploylog=$2 hosts=$3
        local date=$(date "+%Y-%m-%d-%H.%M.%S") stamp=$(date +%s)
        local targets

        local targetlist=$(jq . --raw-input <<<"$hosts" | jq 'split(" ")' -c)
        dprint "deployed hosts: $targetlist"

        jq >"$deployfile" "
          { era:               \"$(get_era)\"
          , topology:          \"$(parmetajq .topology)\"
          , profile:           \"$prof\"
          , timestamp:         ${stamp}
          , date:              \"${date}\"
          , targets:           $targetlist
          , genesis_hash:      \"$(genesis_hash)\"
          , profile_content:   $(profjq "${prof}" .)
          , pins:
            { \"cardano-node\": $(jq '.["cardano-node"].rev' nix/sources.bench.json)
            , \"cardano-ops\":  \"$(git rev-parse HEAD)\"
            }
          , ops_modified:      $(if git diff --quiet --exit-code
                                 then echo false; else echo true; fi)
          }
          " --null-input
        oprint "updated deployment state record"
}

deploystate_destroy() {
        local cmd=()

        oprint "destroying deployment"
        rm -f "$deployfile"
        if nixops 'info' >/dev/null 2>&1
        then nixops 'destroy' --confirm
             nixops 'delete'  --confirm; fi
}

deploystate_create() {
        nixops create ./deployments/cardano-aws.nix -I nixpkgs=./nix
}

deploystate_deploy_profile() {
        local prof=$1 hosts=$2 deploylog=$3 nodesrc=$4 nodesrcspec=$5
        local era topology include node_rev ops_rev ops_checkout_state

        era=$(get_era)
        topology=$(parmetajq .topology)
        node_rev=$(jq --raw-output '.rev' <<<$nodesrc)
        ops_rev=$(git rev-parse HEAD)
        ops_branch=$(maybe_local_repo_branch . ${ops_rev})
        ops_checkout_state=$(git diff --quiet --exit-code || echo '(modified)')
        nodesrcnix=$(nix-instantiate --eval \
                                     -E "{ json }: __fromJSON json" \
                                     --argstr json "$nodesrc")

        if ! nixops info >/dev/null 2>&1
        then oprint "nixops info returned status $?, creating deployment.."
             deploystate_create
        fi

        cat <<EOF
--( deploying profile $prof
--(   era:           $era
--(   topology:      $topology
--(   node:          $node_rev / $nodesrcspec
--(   ops:           $ops_rev / $ops_branch  $ops_checkout_state
--(   generator:     $(profjq "$prof" .generator --compact-output)
--(   genesis:       $(profjq "$prof" .genesis   --compact-output)
--(   node:          $(profjq "$prof" .node      --compact-output)
EOF

        set +o pipefail
        local host_resources other_resources
        host_resources=($hosts)
        host_resources_real=($(nixops info --plain 2>/dev/null | sed 's/^\([a-zA-Z0-9-]*\).*/\1/' | grep -ve '-ip$\|cardano-keypair-\|allow-\|relays-'))
        other_resources=($(nixops info --plain 2>/dev/null | sed 's/^\([a-zA-Z0-9-]*\).*/\1/' | grep  -e '-ip$\|cardano-keypair-\|allow-\|relays-'))
        set -o pipefail

        test "${host_resources[*]}" = "${host_resources_real[*]}" ||
            fail "requested deployment host set does not match NixOps deployment host set:  nixops (${host_resources_real[*]}) != requested (${host_resources[*]})"

        local host_count=${#host_resources[*]}
        oprint "hosts to deploy:  $host_count total:  ${host_resources[*]}"

        local max_batch=10
        if test $host_count -gt $max_batch
        then oprint "that's too much for a single deploy -- deploying in batches of $max_batch nodes"

             oprint "deploying non-host resources first:  ${other_resources[*]}"
             time deploy_resources "$prof" "$nodesrcnix" "$deploylog" \
                                   ${other_resources[*]}

             local base=0 batch
             while test $base -lt $host_count
             do local batch=(${host_resources[*]:$base:$max_batch})
                oprint "deploying host batch:  ${batch[*]}"
                time deploy_resources "$prof" "$nodesrcnix" "$deploylog" ${batch[*]}
                oprint "deployed batch of ${#batch[*]} nodes:  ${batch[*]}"
                base=$((base + max_batch))
             done
        else oprint "that's deployable in one go -- blasting ahead"
             time deploy_resources "$prof" "$nodesrcnix" "$deploylog"
        fi

        oprint_ne "freeing disc space on: "
        for host in $hosts
        do { local disc_usage_pct=$(node_nixos_root_disk_usage_percent $host)
             if test $disc_usage_pct -gt 70
             then echo -n " $host($disc_usage_pct)"
                  nixops ssh $host -- sh -c "'nix-collect-garbage --delete-old >/dev/null 2>&1'"; fi; } &
        done
        time wait

        oprint "deployment complete, recording deployment state.."
        update_deployfile "$prof" "$deploylog" "$hosts"
}

run_nixops_deploy() {
        local prof=$1 deploylog=$2
        shift 2
        local flags=("$@")
        local cmd=(nixops deploy)
        cmd+=("${flags[@]}")

        echo "-------------------- nixops deploy $*" >>"$deploylog"
        if export BENCHMARKING_PROFILE=${prof}; ! "${cmd[@]}" \
                 >>"$deploylog" 2>&1
        then echo "FATAL:  deployment failed, full log in ${deploylog}"
             echo -e "FATAL:  here are the last 200 lines:\n"
             tail -n200 "$deploylog"
             return 1
        fi >&2
}

deploy_build_only() {
        local prof=$1 nodesrcnix=$2 deploylog=$3
                # --arg 'sourcesOverridesDirect' "{ cardano_node = $nodesrcnix; }" \
        run_nixops_deploy "$prof" "$deploylog" \
                --build-only \
                --confirm \
                --cores 0 \
                -j 4
}

deploy_resources() {
        local prof=$1 nodesrcnix=$2 deploylog=$3
        shift 3
        run_nixops_deploy "$prof" "$deploylog" \
                --allow-reboot \
                --confirm \
                --cores 0 -j 4 \
                --max-concurrent-copy 50 \
                ${1:+--include} "$@"
}

op_stop() {
        nixops ssh-for-each --parallel "systemctl stop cardano-node 2>/dev/null || true" &
        nixops ssh-for-each --parallel "systemctl stop systemd-journald 2>/dev/null || true" &
        wait
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

op_fetch_utxo() {
    local node=${1:-explorer}
    local tag=$(cluster_last_meta_tag)
    local file='runs/'$tag/utxo.$(date +%s).json

    oprint "querying UTxO on $node.."
    fetch_utxo "$(cluster_last_meta_tag)" 'explorer'
}
