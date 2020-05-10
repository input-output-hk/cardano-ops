#!/usr/bin/env bash

generate_run_id() {
        local prof="$1"
        local node=$(jq --raw-output '.["cardano-node"].rev' nix/sources.json | cut -c-8)
        local tx=$(jq  .[\"${prof}\"].txCount      ${clusterfile})
        local l=$(jq   .[\"${prof}\"].addTxSize    ${clusterfile})
        local i=$(jq   .[\"${prof}\"].inputsPerTx  ${clusterfile})
        local o=$(jq   .[\"${prof}\"].outputsPerTx ${clusterfile})
        local tps=$(jq .[\"${prof}\"].tps          ${clusterfile})
        echo "$(generate_mnemonic).node-${node}.tx${tx}.l${l}.i${i}.o${o}.tps${tps}"
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
              ' last-run.json)"
}

goggles() {
        ${goggles_fn}
}
export -f goggles goggles_ip
