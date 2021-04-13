#!/usr/bin/env bash
# shellcheck disable=1091,2016

analysis_list+=()
analysis_message_types() {
        local dir=${1:-.} mach tnum sub_tids; shift
        local machines=("$@")

        for mach in ${machines[*]}
        do echo -n .$mach >&2
           local types key
           "$dir"/tools/msgtypes.sh \
             "$dir/analysis/logs-$mach"/node-*.json |
           while read -r ty
                 test -n "$ty"
           do key=$(jq .kind <<<$ty -r | sed 's_.*\.__g')
              jq '{ key: .kind, value: $count }' <<<$ty \
                --argjson count "$(grep -Fh "$key\"" \
                                     "$dir/analysis/logs-$mach"/node-*.json |
                                   wc -l)"
           done |
           jq '{ "\($name)": from_entries }
               '  --slurp --arg name "$mach"
           # jq '{ "\($name)": $types }
           #     ' --arg     name  "$mach" --null-input \
           #       --argjson types "$("$dir"/tools/msgtypes.sh \
           #                          "$dir/analysis/logs-$mach"/node-*.json |
           #                          jq . --slurp)"
        done | analysis_append "$dir" \
                 '{ message_types: add
                  }' --slurp
}

analysis_list+=()
analysis_tx_losses() {
        local dir=${1:-.}
        dir=$(realpath "$dir")

        pushd "$dir"/analysis >/dev/null || return 1
        if jqtest '(.tx_stats.tx_missing != 0)' "$dir"/analysis.json
        then echo -n " missing-txs"
             . "$dir"/tools/lib-loganalysis.sh
             op_analyse_losses; fi
        popd >/dev/null || return 1
}
