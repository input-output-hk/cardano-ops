#!/usr/bin/env bash
# shellcheck disable=1091,2016


logs_of_nodes() {
        local dir=$1; shift
        local machines=("$@")

        for mach in ${machines[*]}
        do ls -- "$dir"/analysis/logs-"$mach"/node-*.json; done
}

collect_jsonlog_inventory() {
        local dir=$1; shift
        local constituents=("$@")

        for mach in ${constituents[*]}
        do jsons=($(ls -- "$dir"/logs-"$mach"/node-*.json))
           jsonlog_inventory "$mach" "${jsons[@]}"; done
        jsonlog_inventory "generator" "$dir"/logs-explorer/generator-*.json
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

analyse_run() {
        while test $# -ge 1
        do case "$1" in
           --list ) echo ${analysis_list[*]}; return;;
           * ) break;; esac; shift; done

        local dir=${1:-.} tag meta
        dir=$(realpath "$dir")

        if test ! -d "$dir"
        then fail "run directory doesn't exist: $dir"; fi
        if test ! -f "$dir/meta.json"
        then fail "run directory doesn't has no metafile: $dir"; fi
        run_fetch_benchmarking "$dir/tools"

        machines=($(jq '.machine_info | keys | join(" ")
                       ' --raw-output <"$dir/deployment-explorer.json"))
        meta=$(jq .meta "$dir/meta.json")
        tag=$(jq .tag <<<$meta --raw-output)

        echo "--( processing logs in:  $(basename "$dir")"

        for a in "${analysis_list[@]}"
        do echo -n " $a" | sed 's/analysis_//'
           $a "$dir" "${machines[@]}"; done

        patch_run "$dir"

        # rm -rf "$dir"/analysis/{analysis,logs-node-*,logs-explorer,startup}

        oprint "analysed tag:  ${tag}"
}

runs_in() {
        local dir=${1:-.}
        dir=$(realpath $dir)
        find "$dir" -maxdepth 2 -mindepth 2 -name meta.json -type f | cut -d/ -f$(($(tr -cd /  <<<$dir | wc -c) + 2))
}

mass_analyse() {
        local parallel=
        while test $# -ge 1
        do case "$1" in
           --parallel ) parallel=t;;
           * ) break;; esac; shift; done

        local dir=${1:-.} runs
        runs=($(runs_in "$dir"))

        oprint "analysing runs:  ${runs[*]}"

        for run in "${runs[@]}"
        do if test -n "$parallel"
           then analyse_run "$dir/$run" &
           else analyse_run "$dir/$run"; fi; done
}
