#!/usr/bin/env bash

generate_run_tag() {
        local batch=$1 prof=$2

        echo "$(date +'%Y'-'%m'-'%d'-'%H.%M').$batch.$prof"
}

run_report_name() {
        local metafile meta prof suffix=
        dir=${1:-.}
        metafile="$dir"/meta.json
        meta=$(jq .meta "$metafile" --raw-output)
        batch=$(jq .batch  <<<$meta --raw-output)
        prof=$(jq .profile <<<$meta --raw-output)
        date=$(date +'%Y'-'%m'-'%d'-'%H%M' --date=@"$(jq .timestamp <<<$meta)")

        test -n "$meta" -a -n "$prof" ||
                fail "Bad run meta.json format:  $metafile"

        if is_run_broken "$dir"
        then suffix='broken'; fi

        echo "$date.$batch.$prof${suffix:+.$suffix}"
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
        fetch_run      "$dir"
        analyse_run    "$dir"
        package_run    "$dir" "$(realpath ../bench-results-bad)"
}

