#!/usr/bin/env bash
# shellcheck disable=2155

function node_runtime_config_filepath() {
    nixops ssh $1 -- pgrep -fal 'cardano-node\ run' |
        sed 's_.*--config \([^ ]*\).*_\1_'
}

function node_runtime_genesis_filepath() {
    local node_config=$(node_runtime_config_filepath $1)
    local era=$2

    if test -n "$node_config"
    then nixops ssh $1 -- jq -r ".${era}GenesisFile" "$node_config"
    else fail "node_runtime_genesis_filepath: node process not running on $1"; fi
}

function node_runtime_genesis() {
    local node_genesis=$(node_runtime_genesis_filepath $1 $2)

    if test -n "$node_genesis"
    then nixops ssh $1 -- jq . $node_genesis
    else fail "node_runtime_genesis: node process not running on $1"; fi
}

function node_runtime_genesis_systemstart() {
    local node_genesis=$(node_runtime_genesis_filepath $1 'Shelley')

    if test -n "$node_genesis"
    then nixops ssh $1 -- jq  -r '.systemStart' $node_genesis
    else fail "node_runtime_genesis_systemstart: node process not running on $1"; fi
}

## A leadership check gives us current time and current slot.
## Here we rely on that not to be delayed beyond its second.
function node_runtime_apparent_systemstart() {
    nixops ssh $1 -- sh -c '"journalctl -u cardano-node | grep TraceStartLeadershipCheck | head -n2 | tail -n1"' |
        cut -d':' -f4- |
        jq '[ (.at | "\(.[:19])Z" | fromdateiso8601)
            , .data.slot
            ] | .[0] - .[1] | todateiso8601' -r
}

function node_runtime_log_commit_id() {
    local mach=$1

    set +o pipefail
    nixops ssh "$mach" -- journalctl -u cardano-node |
        grep commit |
        tail -n1 |
        sed 's/.*"\([0-9a-f]\{40\}\)".*/\1/'
    set -o pipefail
}

function node_nixos_root_disk_usage_percent() {
    nixops ssh $1 -- df --total --sync --output=source,pcent |
        grep '/dev/disk/by-label/nixos' |
        sed 's_.* [ ]*__; s_%__'
}

function node_effective_service_config() {
    local mach=$1 svc=$2

    local svcfilename execstart configfilename
    svcfilename=$(nixops ssh "$mach" -- \
                         sh -c "'systemctl status $svc || true'" 2>&1 |
                      grep "/nix/store/.*/$svc\.service" |
                      cut -d'(' -f2 | cut -d';' -f1 ||
                      fail "Failed to fetch & parse status of '$svc' on '$mach'")
    execstart=$(nixops ssh "$mach" -- \
                       grep ExecStart= "$svcfilename" |
                    cut -d= -f2 ||
                    fail "Failed to extract ExecStart from service file '$svcfilename' on '$mach'")
    test -n "$execstart" || \
                fail "Couldn't determine ExecStart for '$svc' on '$mach'"
    configfilename=$(nixops ssh "$mach" -- \
                            grep -e '-config.*\.json' "$execstart"  |
                         sed 's_^.*\(/nix/store/.*\.json\).*_\1_' |
                         head -n1 ||
                         fail "Failed to fetch & parse ExecStart of '$svc' on '$mach'")
    test -n "$configfilename" || \
        fail "Couldn't determine config file name for '$svc' on '$mach'"
    nixops ssh "$mach" -- jq . "$configfilename" ||
        fail "Failed to fetch config file for '$svc' on '$mach'"
}

function cluster_machine_infos() {
    local cmd
    cmd=(
        eval echo
        '\"$(hostname)\": { \"local_ip\": \"$(ip addr show scope global | sed -n "/^    inet / s_.*inet \([0-9\.]*\)/.*_\1_; T skip; p; :skip")\", \"public_ip\": \"$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)\", \"placement\": \"$(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)\", \"timestamp\": $(date +%s), \"timestamp_readable\": \"$(date)\" }'
    )
    nixops ssh-for-each --parallel -- "${cmd[@]@Q}" 2>&1 | cut -d'>' -f2-
}

