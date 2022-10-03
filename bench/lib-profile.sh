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
        local batch=$1 prof=$2 nodesrc=$3 nodesrcspec=$4
        prof=$(params resolve-profile "$prof")

        ## 0. Allocate deployment log
        mkdir -p runs/deploy-logs
        local deploylog=runs/deploy-logs/$(timestamp).$batch.$prof.log
        mkdir -p "$(dirname "$deploylog")"
        echo >"$deploylog"
        ln -sf "$deploylog" 'last-deploy.log'

        ## 1. Prebuild
        if test -z "$no_prebuild"
        then oprint "prebuilding profile:  $prof"
             ensure_genesis "$prof"
             local nodesrcnix=$(nix-instantiate \
                                    --eval \
                                    -E "{ json }: __fromJSON json" \
                                    --argstr json "$nodesrc")
             time deploy_build_only "$prof" "$nodesrcnix" "$deploylog"
             oprint "profile prebuild done"
             fi

        ## 2. Prepare final genesis
        ensure_genesis "$prof" 'verbose-please'
        oprint "final deployment genesis ready"

        ## 3. Actually deploy
        deploystate_deploy_profile \
            "$prof" "explorer $(params producers)" "$deploylog" "$nodesrc" "$nodesrcspec"
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
