#!/usr/bin/env bash
# shellcheck disable=1091,2016

analysis_list=()

analysis_list+=(analysis_cleanup)
analysis_cleanup() {
        local dir=${1:-.}

        rm -f    "$dir"/analysis.json
        rm -rf   "$dir"/analysis
        mkdir -p "$dir"/analysis
}

analysis_list+=(analysis_block_arrivals)
analysis_block_arrivals() {
        local dir=${1:-.}
        cat "$dir"/logs/block-arrivals.gauge
        json_file_append "$dir"/analysis.json '
          { block_arrivals: $arrivals
          }' --rawfile arrivals "$dir"/logs/block-arrivals.gauge <<<0
}

analysis_list+=(analysis_unpack)
analysis_unpack() {
        local dir=${1:-.}

        tar x -C "$dir"/analysis -af "$dir"/logs/logs-explorer.tar.xz
        tar x -C "$dir"/analysis -af "$dir"/logs/logs-nodes.tar.xz
        tar x -C "$dir"/analysis -af "$dir"/logs/db-analysis.tar.xz '00-results-table.sql.csv'
}

analysis_list+=(analysis_log_inventory)
analysis_log_inventory()
{
        local dir=${1:-.}; shift
        local machines=("$@")

        collect_jsonlog_inventory "$dir"/analysis "${machines[@]}" \
          > "$dir"/analysis/log-inventory.json

        json_file_append "$dir"/analysis.json \
          '{ final_log_timestamp:      ($logs | max_by(.latest) | .latest)
           , first_node_log_timestamp: ($logs
                                       | map (select(.name != "explorer" and
                                                     .name != "generator"))
                                       | min_by(.earliest) | .earliest)
           , final_node_log_timestamp: ($logs
                                       | map (select(.name != "explorer" and
                                                     .name != "generator"))
                                       | max_by(.latest) | .latest)
           , logs:                $logs
           }' --slurpfile logs "$dir"/analysis/log-inventory.json <<<0
}

analysis_list+=(analysis_dbsync_slot_span)
analysis_dbsync_slot_span() {
        local dir=${1:-.}; shift
        local machines=("$@")
        local fst_nodes last_nodes logs

        logs=($(logs_of_nodes "$dir" "${machines[@]}"))

        fst_nodes=$(grep -Fh '"TraceStartLeadershipCheck"' "${logs[@]}" |
                     sort | head -n1 | jq .data.slot)
        last_nodes=$(grep -Fh '"TraceStartLeadershipCheck"' "${logs[@]}" |
                     sort | tail -n1 | jq .data.slot)
        args=(--argjson fst_dbsync  "$(grep -E '^[0-9]+' "$dir"/analysis/00-results-table.sql.csv | head -n1 | cut -d, -f1 || echo $fst_nodes)"
              --argjson last_dbsync "$(grep -E '^[0-9]+' "$dir"/analysis/00-results-table.sql.csv | tail -n1 | cut -d, -f1 || echo $last_nodes)"
              --argjson fst_nodes  "$fst_nodes"
              --argjson last_nodes "$last_nodes"
        )
        json_file_prepend "$dir"/analysis.json \
          '{ slot_spans:
             { db_sync: { first: $fst_dbsync, last: $last_dbsync }
             , nodes:   { first: $fst_nodes,  last: $last_nodes }
             }
           }' "${args[@]}" <<<0
}

analysis_list+=(analysis_timetoblock)
analysis_timetoblock() {
        local dir=${1:-.}
        dir=$(realpath "$dir")

        pushd "$dir"/analysis >/dev/null || return 1

        "$dir"/tools/analyse.sh   \
          logs-explorer/generator \
          logs-explorer/node      \
          "$dir"/analysis

        cp -f analysis/*.{csv,json} .

        popd >/dev/null || return 1

        json_file_prepend "$dir"/analysis.json \
          '{ tx_stats:            $txstats[0]
           }' --slurpfile txstats "$dir"/analysis/tx-stats.json <<<0
}

analysis_list+=(analysis_submission_threads)
analysis_submission_threads() {
        local dir=${1:-.} sub_tids tnum

        sub_tids="$("$dir"/tools/generator-logs.sh log-tids \
                      "$dir"/analysis/logs-explorer/generator.json || true)"
        json_file_append "$dir"/analysis.json \
          '{ submission_tids: '"$(jq --slurp <<<$sub_tids)"' }' <<<0

        for tnum in $(seq 0 $(($(echo "$sub_tids" | wc -w) - 1)))
        do "$dir"/tools/generator-logs.sh tid-trace "${tnum}" \
             "$dir"/analysis/logs-explorer/generator.json \
             > "$dir"/analysis/generator.submission-thread-trace."${tnum}".json
        done
}

analysis_list+=(analysis_from_benchmarking)
analysis_from_benchmarking() {
        local dir=${1:-.}
        local analysis aname files

        files=($(ls -- "$dir"/analysis/logs-node-*/node-*.json 2>/dev/null || true))
        if test ${#files[*]} -gt 0
        then for analysis in $(ls -- "$dir"/tools/node.*.sh 2>/dev/null || true)
             do aname=$(sed 's_^.*/node\.\(.*\)\.sh$_\1_' <<<$analysis)
                echo -n " $aname.node"
                "$dir"/tools/node."$aname".sh  "${files[@]}" \
                  > "$dir"/analysis/node."$aname".json
                test -x "$dir"/tools/tocsv."$aname".sh &&
                "$dir"/tools/tocsv."$aname".sh \
                  < "$dir"/analysis/node."$aname".json \
                  > "$dir"/analysis/node."$aname".csv; done; fi

        files=($(ls -- "$dir"/analysis/logs-explorer/node-*.json 2>/dev/null || true))
        if test ${#files[*]} -gt 0
        then for analysis in $(ls -- "$dir"/tools/explorer.*.sh 2>/dev/null || true)
             do aname=$(sed 's_^.*/explorer\.\(.*\)\.sh$_\1_' <<<$analysis)
                echo -n " $aname.explorer"
                "$dir"/tools/explorer."$aname".sh  "${files[@]}" \
                  > "$dir"/analysis/explorer."$aname".json
                test -x "$dir"/tools/tocsv."$aname".sh &&
                "$dir"/tools/tocsv."$aname".sh \
                  < "$dir"/analysis/explorer."$aname".json \
                  > "$dir"/analysis/explorer."$aname".csv; done; fi

        files=($(ls -- "$dir"/analysis/logs-explorer/generator*json 2>/dev/null || true))
        if test ${#files[*]} -gt 0
        then for analysis in $(ls -- "$dir"/tools/generator.*.sh 2>/dev/null || true)
             do aname=$(sed 's_^.*/generator\.\(.*\)\.sh$_\1_' <<<$analysis)
                echo -n " $aname.generator"
                "$dir"/tools/generator."$aname".sh  "${files[@]}" \
                  > "$dir"/analysis/generator."$aname".json
                test -x "$dir"/tools/tocsv."$aname".sh &&
                "$dir"/tools/tocsv."$aname".sh \
                  < "$dir"/analysis/generator."$aname".json \
                  > "$dir"/analysis/generator."$aname".csv; done; fi
}

analysis_list+=(analysis_TraceForgeInvalidBlock)
analysis_TraceForgeInvalidBlock() {
        local dir=${1:-.} msg

        msg=$(echo ${FUNCNAME[0]} | cut -d_ -f2)
        files=($(ls -- "$dir"/analysis/logs-node-*/node-*.json 2>/dev/null || true))
        if test ${#files[*]} -eq 0
        then return; fi

        grep --quiet --no-filename -F "\"$msg\"" "${files[@]}" || true |
        jq 'def katip_timestamp_to_iso8601:
              .[:-4] + "Z";
           .
           | map
             ( (.at | katip_timestamp_to_iso8601)
               as $date_iso
             | { date_iso:    $date_iso
               , timestamp:   $date_iso | fromdateiso8601
               , reason:      .data.reason
               , slot:        .data.slot
               }
             )
           | sort_by (.timestamp)
           | .[]
           ' --slurp --compact-output > "$dir"/analysis/node."$msg".json
}

analysis_list+=(analysis_message_types)
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

analysis_list+=(analysis_repackage_db)
analysis_repackage_db() {
        local dir=${1:-.}

        tar x -C "$dir"/analysis -af "$dir"/logs/db-analysis.tar.xz \
            --wildcards '*.csv' '*.txt'
}

# TODO: broken
# analysis_list+=(analysis_tx_losses)
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

analysis_list+=(analysis_derived)
analysis_derived() {
        local dir=${1:-.}
        local f="$dir"/analysis/node.TraceMempoolRejectedTx.json

        analysis_append "$dir" \
          '{ tx_stats:
               ($analysis.tx_stats
                + { tx_rejected:      $rejected
                  , tx_utxo_invalid:  $utxo_invalid
                  , tx_missing_input: $missing_input })}
          ' --argjson rejected      "$(wc   -l <$f || echo 0)" \
            --argjson utxo_invalid  "$(grep -F "(UTxOValidationUTxOError " $f | wc -l)" \
            --argjson missing_input "$(grep -F "(UTxOMissingInput " $f | wc -l)" \
            <<<0
}

analysis_list+=(analysis_sanity)
analysis_sanity() {
        local dir=${1:-.} tag errors
        tag=$(run_tag "$dir")

        errors="$(sanity_check_run "$dir")"
        if test "$errors" != "[]"
        then echo
             oprint "sanity check failed for tag:  $tag"
             echo "$errors" >&2
             mark_run_broken "$dir" "$errors"
             return 1; fi
}

###
### Aux
###
jsonlog_inventory() {
        local name=$1; shift
        local args fs=("$@")

        args=(--arg     name     "$name"
              --argjson earliest "$(head -n1 ${fs[0]})"
              --argjson latest   "$(tail -n1 ${fs[-1]})"
              --argjson files    "$(echo ${fs[*]} | shell_list_to_json)"
        )
        jq 'def katip_timestamp_to_iso8601:
              .[:-4] + "Z";
           .
           | { name:     $name
             , earliest: ($earliest.at
                         | katip_timestamp_to_iso8601 | fromdateiso8601)
             , latest:   (  $latest.at
                         | katip_timestamp_to_iso8601 | fromdateiso8601)
             , files:    $files
             }' "${args[@]}" <<<0
}
