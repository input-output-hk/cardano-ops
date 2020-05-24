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
        test -n "${nix_store_benchmarking}" ||
                fail "couldn't fetch 'cardano-benchmarking'"
        mkdir -p 'tools'
        cp -fa "${nix_store_benchmarking}"/scripts/*.{sh,sql} "$targetdir"
}

is_run_broken() {
        local tag=$1
        dir="./runs/${tag}"

        jqtest .broken "$dir"/meta.json
}

mark_run_broken() {
        local tag metatmp
        tag=${1:-$(cluster_last_meta_tag)}
        dir="./runs/${tag}"

        oprint "marking run as broken (results will be stored separately):  $tag"
        metatmp=$(mktemp --tmpdir)
        jq '{ broken: true } + .
           ' >"$metatmp" <"$dir/meta.json"
        mv    "$metatmp"  "$dir/meta.json"
}

process_broken_run() {
        local tag=$1 metatmp

        tagroot=$(realpath ./runs)
        resultroot=$(realpath ../bench-results-bad)
        export tagroot resultroot

        op_stop
        op_bench_fetch  "$tag"
        mark_run_broken "$tag"
        package_tag     "$tag"
}

