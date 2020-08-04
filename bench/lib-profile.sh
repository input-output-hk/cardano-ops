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

        ## Determine if genesis update is necessary:
        ## 1. old enough?
        ## 2. profile incompatible?
        regenesis_causes=()

        if test -n "${force_genesis}"
        then regenesis_causes+=('--genesis'); fi

        if   ! genesisjq . >/dev/null 2>&1
        then regenesis_causes+=('missing-or-malformed-genesis-metadata')
        else
             if ! genesis_check_age "$(genesisjq .start_time)"
             then regenesis_causes+=('local-genesis-old-age'); fi
             if   njqtest "
                  $(genesisjq .params) !=
                  $(profjq "${prof}" .genesis)"
             then regenesis_causes+=('profile-requires-new-genesis'); fi; fi

        if test -n "${regenesis_causes[*]}"
        then oprint "regenerating genesis, because:  ${regenesis_causes[*]}"
             local genesislog
             genesislog=runs/$(timestamp).genesis.$prof.log
             profile_genesis "$prof" >"$genesislog" 2>&1 || {
                     fprint "genesis generation failed:"
                     cat "$genesislog" >&2
                     exit 1
             }; fi

        redeploy_causes=(mandatory)
        include=('explorer')

        if   test ! -f "${deployfile['explorer']}"
        then redeploy_causes+=(missing-explorer-deployfile)
             include+=('explorer')
        elif ! depljq 'explorer' . >/dev/null 2>&1
        then redeploy_causes+=(malformed-explorer-deployfile)
             include+=('explorer')
        elif njqtest "
             ($(depljq 'explorer' .profile)         != \"$prof\") or
             ($(depljq 'explorer' .profile_content) != $(profjq "$prof" .))"
        then redeploy_causes+=(new-profile)
             include+=('explorer')
        elif njqtest "
             $(genesisjq .params 2>/dev/null || echo '"missing"') !=
             $(depljq 'explorer' .profile_content.genesis)"
        then redeploy_causes+=(genesis-params-explorer)
             include+=('explorer')
        elif njqtest "
             $(genesisjq .hash 2>/dev/null || echo '"missing"') !=
             $(depljq 'explorer' .genesis_hash)"
        then redeploy_causes+=(genesis-hash-explorer)
             include+=('explorer'); fi


        if test ! -f "${deployfile['producers']}"
        then redeploy_causes+=(missing-producers-deployfile)
             include+=($(params producers))
        elif ! depljq 'producers' . >/dev/null 2>&1
        then redeploy_causes+=(malformed-producers-deployfile)
             include+=($(params producers))
        elif njqtest "
             $(genesisjq .params 2>/dev/null || echo '"missing"') !=
             $(depljq 'producers' .profile_content.genesis)"
        then redeploy_causes+=(genesis-params-producers)
             include+=($(params producers))
        elif njqtest "
             $(genesisjq .hash 2>/dev/null || echo '"missing"') !=
             $(depljq 'producers' .genesis_hash)"
        then redeploy_causes+=(genesis-hash-producers)
             include+=($(params producers)); fi

        if test -n "${force_deploy}"
        then redeploy_causes+=('--deploy')
             include=('explorer' $(params producers)); fi

        local final_include
        if test "${include[0]}" = "${include[1]:-}"
        then final_include=$(echo "${include[*]}" | sed 's/explorer explorer/explorer/g')
        else final_include="${include[*]}"; fi

        if test "$final_include" = "explorer $(params producers)"
        then qualifier='full'
        elif test "$final_include" = "$(params producers)"
        then qualifier='producers'
        else qualifier='explorer'; fi

        if test -z "${redeploy_causes[*]}"
        then return; fi

        oprint "redeploying, because:  ${redeploy_causes[*]}"
        deploylog=runs/$(timestamp).deploy.$qualifier.$prof.log
        if test -z "$no_deploy"
        then deploystate_deploy_profile "$prof" "$final_include" "$deploylog"
        else oprint "skippin' deploy, because:  CLI override"
             echo "DEPLOYMENT_METADATA=" > "$deploylog"
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
