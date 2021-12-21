#!/usr/bin/env bash
# shellcheck disable=1091,2016


logs_of_nodes() {
        local dir=$1; shift
        local machines=("$@")

        for mach in ${machines[*]}
        do ls -- "$dir"/analysis/$mach/node-*.json; done
}

collect_jsonlog_inventory() {
        local dir=$1; shift
        local constituents=("$@")

        for mach in ${constituents[*]}
        do jsons=($(ls -- "$dir"/$mach/node-*.json))
           jsonlog_inventory "$mach" "${jsons[@]}"; done
        jsonlog_inventory "generator" "$dir"/explorer/generator-*.json
}

analysis_append() {
        local dir=$1 expr=$2; shift 2
        json_file_append "$dir"/analysis.json '
            $meta[0]     as $meta
          | $analysis[0] as $analysis
          | '"$expr
          " --slurpfile meta     "$dir/meta.json" \
            --slurpfile analysis "$dir/analysis.json" \
            "$@"
}

analysis_prepend() {
        local dir=$1 expr=$2; shift 2
        json_file_prepend "$dir"/analysis.json '
            $meta[0]     as $meta
          | $analysis[0] as $analysis
          | '"$expr
          " --slurpfile meta     "$dir/meta.json" \
            --slurpfile analysis "$dir/analysis.json" \
            "$@"
}

###
###

runs_in() {
        local dir=${1:-.}
        dir=$(realpath $dir)
        find "$dir" -maxdepth 2 -mindepth 2 -name meta.json -type f | cut -d/ -f$(($(tr -cd /  <<<$dir | wc -c) + 2))
}
