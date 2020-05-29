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

        if test "$(head -n1 "$dir"/analysis/00-results-table.sql.csv)" \
                == "DROP TABLE"
        then echo "---| patching $dir/analysis/00-results-table.sql.csv"
             tail -n+3 "$dir"/analysis/00-results-table.sql.csv \
               > "$dir"/analysis/00-results-table.sql.csv.fixed
             mv "$dir"/analysis/00-results-table.sql.csv.fixed \
                "$dir"/analysis/00-results-table.sql.csv;
        fi
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

package_run() {
        local tag report_name package
        dir=${1:-.}
        tag=$(run_tag "$dir")
        report_name=$(run_report_name "$dir")

        if is_run_broken "$dir"
        then resultroot=$(realpath ../bench-results-bad)
        else resultroot=$(realpath ../bench-results); fi

        package=${resultroot}/$report_name.tar.xz

        oprint "Packaging $tag as:  $package"
        ln -sf "./runs/$tag" "$report_name"
        tar cf "$package"    "$report_name" --xz --dereference
        rm -f                "$report_name"
}
