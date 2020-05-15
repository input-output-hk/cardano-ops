#!/usr/bin/env bash

generate_run_id() {
        local prof="$1" node tx l i o tps
        node=$(jq --raw-output '.["cardano-node"].rev' nix/sources.json | cut -c-8)
        tx=$(jq  .[\"${prof}\"].tx_count       ${clusterfile})
        l=$(jq   .[\"${prof}\"].add_tx_size    ${clusterfile})
        i=$(jq   .[\"${prof}\"].inputs_per_tx  ${clusterfile})
        o=$(jq   .[\"${prof}\"].outputs_per_tx ${clusterfile})
        tps=$(jq .[\"${prof}\"].tps            ${clusterfile})
        echo "$(generate_mnemonic).node-${node}.tx${tx}.l${l}.i${i}.o${o}.tps${tps}"
}

export nix_store_benchmarking=
run_fetch_benchmarking() {
        local targetdir=$1
        if test -z "${nix_store_benchmarking}"
        then echo "--( Fetching tools from 'cardano-benchmarking' $(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.rev" | tr -d '"' | cut -c-8) .."
             export nix_store_benchmarking=$(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.outPath" | tr -d '"' )
             test -n "${nix_store_benchmarking}" ||
                     fail "couldn't fetch 'cardano-benchmarking'"
             mkdir -p 'tools'
             cp -fa "${nix_store_benchmarking}"/scripts/*.{sh,sql} "$targetdir"; fi
}
