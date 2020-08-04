#!/usr/bin/env bash
# shellcheck disable=2155


fetch_effective_service_node_config() {
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
                         grep -e '-config-.*\.json' "$execstart"  |
                         sed 's_^.*\(/nix/store/.*\.json\).*_\1_' |
                         head -n1 ||
                         fail "Failed to fetch & parse ExecStart of '$svc' on '$mach'")
        test -n "$configfilename" || \
                fail "Couldn't determine config file name for '$svc' on '$mach'"
        nixops ssh "$mach" -- jq . "$configfilename" ||
                fail "Failed to fetch config file for '$svc' on '$mach'"
}

fetch_effective_service_node_configs() {
        local rundir=$1; shift; local nodes=($*)

        local cfroot="$rundir"/configs mach
        mkdir -p "$cfroot"
        for mach in ${nodes[*]} 'explorer'
        do fetch_effective_service_node_config "$mach" 'cardano-node' \
              > "$cfroot"/"$mach"-cardano-node.config.json &
        done
        fetch_effective_service_node_config 'explorer' 'tx-generator' \
              > "$cfroot"/explorer-tx-generator.config.json
}
