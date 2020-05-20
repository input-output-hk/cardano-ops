#!/usr/bin/env bash
# shellcheck disable=1091

tmjq() {
        jq .meta "${archive}/$1/"meta.json  --raw-output
}

tag_report_name() {
        local tag=${1?missing tag} meta prof
        local metafile=${archive}/$tag/meta.json
        meta=$(jq .meta "$metafile" --raw-output)
        prof=$(jq .profile --raw-output <<<$meta)
        date=$(date +'%Y'-'%m'-'%d'-'%H.%S' --date=@"$(jq .timestamp <<<$meta)")

        test -n "$meta" -a -n "$prof" ||
                fail "Bad tag meta.json format:  $metafile"

        echo "$date.$prof"
}

package_tag() {
        local tag=$1 package report_name
        report_name=$(tag_report_name "$tag")
        package=$report_name.tar.xz

        oprint "Packaging $tag as:  $package"
        ln -sf "./runs/$tag" "$report_name"
        tar cf "$package"    "$report_name" --xz --dereference
        rm -f                "$report_name"
}

analyse_tag() {
        local tag dir meta
        tag=${1?ERROR:  analyse_tag reqires a tag}
        dir="${archive}/${tag}"

        pushd "${dir}" >/dev/null || return 1
        rm -rf 'analysis'
        mkdir  'analysis'
        cd     'analysis'
        meta=$(tmjq "$tag" .)

        oprint "running log analyses: "
        tar xaf '../logs/log-explorer-generator.tar.xz'
        tar xaf '../logs/log-nodes.tar.xz'

        echo " timetoblock.csv"
        ../tools/analyse.sh generator log-explorer "last-run/analysis/"
        cp analysis/timetoblock.csv .

        local blocks
        blocks="$(../tools/blocksizes.sh log-explorer.json |
        echo -n "--( running log analyses:  blocksizes"
                               jq . --slurp)"

        declare -A msgtys
        local mach msgtys=() producers tnum msgtys_generator sub_tids
        producers=($(jq '.nixops.benchmarkingTopology.coreNodes
                        | map(.name) | join(" ")' --raw-output <<<$meta))

        for mach in explorer ${producers[*]}
        do echo -n " msgtys:${mach}"
           msgtys[${mach}]="$(../tools/msgtypes.sh log-explorer.json |
                              jq . --slurp)"; done
        echo -n " msgtys:generator"
        msgtys_generator="$(../tools/msgtypes.sh generator.json |
                               jq . --slurp)"

        echo -n " node-to-node-submission-tids"
        sub_tids="$(../tools/generator-logs.sh log-tids generator.json)"
        for tnum in $(seq 0 $(($(echo "$sub_tids" | wc -w) - 1)))
        do echo -n " node-to-node-submission:${tnum}"
           ../tools/generator-logs.sh tid-trace "${tnum}" generator.json \
             > generator.submission-thread-trace."${tnum}".json; done

        echo -n " added-to-current-chain"
        ../tools/added-to-current-chain.sh log-explorer.json \
             > explorer.added-to-current-chain.csv

        jq '{ tx_stats: $txstats[0]
            , submission_tids: '"$(jq --slurp <<<$sub_tids)"'
            , MsgBlock:    '"${blocks}"'
            , message_kinds:
              ({ generator: '"${msgtys_generator}"'
               }'"$(for mach in ${!msgtys[*]}
                    do echo " + { \"$mach\": $(jq --slurp <<<${msgtys[$mach]}) }"
                    done)"')
            }' --null-input \
               --slurpfile txstats 'analysis/tx-stats.json' \
               > ../analysis.json

        echo -n " adding db-analysis"
        tar xaf '../logs/db-analysis.tar.xz' --wildcards '*.csv' '*.txt'

        if jqtest '(.tx_stats.tx_missing != 0)' ../analysis.json
        then echo " missing-txs"
             . ../tools/lib-loganalysis.sh
             op_analyse_losses
        else echo
        fi
        patch_local_tag "$tag"

        rm -rf analysis log-node-*.json log-explorer.json generator.json

        popd >/dev/null

        oprint "analysed tag:  ${tag}"
}

tag_format_timetoblock_header="tx id,tx time,block time,block no,delta t"
patch_local_tag() {
        local tag=${1?missing tag} target
        target=${archive}/${tag}
        cd "${target}" >/dev/null || return 1

        if test "$(head -n1 analysis/timetoblock.csv)" != "${tag_format_timetoblock_header}"
        then echo "---| patching ${tag}/analysis/timetoblock.csv"
             sed -i "1 s_^_${tag_format_timetoblock_header}\n_; s_;_,_g" \
                 'analysis/timetoblock.csv'
        fi

        if test "$(head -n1 analysis/00-results-table.sql.csv)" == "DROP TABLE"
        then echo "---| patching ${tag}/analysis/00-results-table.sql.csv"
             tail -n+3 analysis/00-results-table.sql.csv > analysis/00-results-table.sql.csv.fixed
             mv analysis/00-results-table.sql.csv.fixed analysis/00-results-table.sql.csv;
        fi

        cd - >/dev/null || return 1
}
