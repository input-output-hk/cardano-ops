#!/usr/bin/env bash

generate_run_id() {
        local prof="$1" node tx l tps io blks
        node=$(jq --raw-output '.["cardano-node"].rev' nix/sources.bench-txgen-simple.json | cut -c-8)
        tx=$(profjq  "${prof}" .generator.tx_count)
        l=$(profjq   "${prof}" .generator.add_tx_size)
        io=$(profjq  "${prof}" .generator.inputs_per_tx)
        tps=$(profjq "${prof}" .generator.tps)
        blks=$(($(profjq "${prof}" .genesis.max_block_size) / 1000))
        echo "$(generate_mnemonic).node-${node}.tx${tx}.l${l}.tps${tps}.io${io}.blk${blks}"
}

run_fetch_benchmarking() {
        local targetdir=$1
        oprint "fetching tools from 'cardano-benchmarking' $(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.rev" | tr -d '"' | cut -c-8) .."
        export nix_store_benchmarking=$(nix-instantiate --eval -E "(import $(dirname "${self}")/../nix/sources.nix).cardano-benchmarking.outPath" | tr -d '"' )
        test -d "$nix_store_benchmarking" ||
                fail "couldn't fetch 'cardano-benchmarking'"
        mkdir -p "$targetdir"
        cp -fa "$nix_store_benchmarking"/{analyses/*.sh,scripts/*.{sh,sql}} "$targetdir"
}

is_run_broken() {
        local dir=${1:-}

        test -f "$dir"/analysis.json &&
          jqtest .anomalies "$dir"/analysis.json ||
        jqtest .broken    "$dir"/meta.json
}

mark_run_broken() {
        local dir=$1 errors=$2 tag
        tag=$(run_tag "$dir")

        test -n "$2" ||
          fail "asked to mark $tag as anomalous, but no anomalies passed"

        oprint "marking run as broken (results will be stored separately):  $tag"
        json_file_prepend "$dir/analysis.json" '{ anomalies: $anomalies }' \
          --argjson anomalies "$errors" <<<0
}

process_broken_run() {
        local dir=${1:-.}

        op_stop
        op_bench_fetch "$dir"
        analyse_run    "$dir"
        package_run    "$dir" "$(realpath ../bench-results-bad)"
}

