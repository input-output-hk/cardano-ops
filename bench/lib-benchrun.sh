#!/usr/bin/env bash

generate_run_tag() {
        local prof=$1

        echo "$(date +'%Y'-'%m'-'%d'-'%H.%M').$prof"
}

run_report_name() {
        local metafile meta prof suffix=
        dir=${1:-.}
        metafile="$dir"/meta.json
        meta=$(jq .meta "$metafile" --raw-output)
        prof=$(jq .profile <<<$meta --raw-output)
        date=$(date +'%Y'-'%m'-'%d'-'%H.%M' --date=@"$(jq .timestamp <<<$meta)")

        test -n "$meta" -a -n "$prof" ||
                fail "Bad run meta.json format:  $metafile"

        if is_run_broken "$dir"
        then suffix='broken'; fi

        echo "$date.$prof${suffix:+.$suffix}"
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

