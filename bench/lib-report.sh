#!/usr/bin/env bash
# shellcheck disable=1091,2016

tag_format_timetoblock_header="tx id,tx time,block time,block no,delta t"
patch_run() {
        local dir=${1:-.}
        dir=$(realpath "$dir")

        if test "$(head -n1 "$dir"/analysis/timetoblock.csv)" \
                != "${tag_format_timetoblock_header}"
        then echo "---| patching $dir/analysis/timetoblock.csv"
             sed -i "1 s_^_${tag_format_timetoblock_header}\n_; s_;_,_g" \
                 "$dir"/analysis/timetoblock.csv
        fi
}
