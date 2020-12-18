#!/usr/bin/env bash
# shellcheck disable=2086

## Profile JQ
profjq() {
        local prof=$1 q=$2; shift 2
        rparmjq "del(.meta)
                | if has(\"$prof\") then (.\"$prof\" | $q)
                  else error(\"Can't query unknown profile $prof using $q\") end
                " "$@"
}

profgenjq()
{
        local prof=$1 q=$2; shift 2
        profjq "$prof" ".genesis | ($q)" "$@"
}

profile_deploy() {
        local prof="${1:-default}" include=()
        prof=$(params resolve-profile "$prof")

        mkdir -p runs/deploy-logs
        deploylog=runs/deploy-logs/$(timestamp).deploy.$prof.log

        mkdir -p "$(dirname "$deploylog")"
        echo >"$deploylog"
        ln -sf "$deploylog" 'last-deploy.log'

        watcher_pid=
        if test -n "${watch_deploy}"
        then { sleep 0.3; tail -f "$deploylog"; } &
             watcher_pid=$!; fi

        if test -z "$no_prebuild"
        then oprint "prebuilding:"
             ## 0. Prebuild:
             time deploy_build_only "$prof" "$deploylog" "$watcher_pid"; fi

        if test -n "$watcher_pid"
        then kill "$watcher_pid" >/dev/null 2>&1 || true; fi

        ## Determine if genesis update is necessary:
        ## 1. profile incompatible?
        regenesis_causes=(mandatory)

        if   ! genesisjq . >/dev/null 2>&1
        then regenesis_causes+=('missing-or-malformed-genesis-metadata')
        else
             if   njqtest "
                  $(genesisjq .params) !=
                  $(profjq "${prof}" .genesis)"
             then regenesis_causes+=('profile-requires-new-genesis'); fi; fi

        if test -n "${regenesis_causes[*]}"
        then oprint "regenerating genesis, because:  ${regenesis_causes[*]}"
             local genesislog
             genesislog=runs/$(timestamp).genesis.$prof.log
             profile_genesis "$prof" 2>&1 || {
                     fprint "genesis generation failed:"
                     cat "$genesislog" >&2
                     exit 1
             } | tee "$genesislog";
        fi

        include="explorer $(params producers)"

        if test -z "$no_deploy"
        then deploystate_deploy_profile "$prof" "$include" "$deploylog"
        else oprint "skippin' deploy, because:  CLI override"
             ln -sf "$deploylog" 'last-deploy.log'
        fi
}

###
### Aux
###
goggles_fn='cat'

goggles_ip() {
        sed "$(jq --raw-output '.
              | .local_ip  as $local_ip
              | .public_ip as $public_ip
              | ($local_ip  | map ("s_\(.local_ip  | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g")) +
                ($public_ip | map ("s_\(.public_ip | gsub ("\\."; "."; "x"))_HOST-\(.hostname)_g"))
              | join("; ")
              ' last-meta.json)"
}

goggles() {
        ${goggles_fn}
}
export -f goggles goggles_ip
