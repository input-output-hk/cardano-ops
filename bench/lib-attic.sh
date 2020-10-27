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

sanity_check_list+=()
sanity_check_slot_spread_dbsync() {
        local dir=$1 t=${2:-$(jq .meta.profile_content.tolerances $dir/meta.json)}
        sanity_check "$t" "$dir" '
          $analysis.slot_spans
          | (.db_sync.first - .nodes.first | fabs
            | . > $allowed.slot_spread_dbsync_first)
          ' '$analysis.slot_spans
          | { kind:         "slot-spread-dbsync-first"
            , dbsync_first: .db_sync.first
            , nodes_first:  .nodes.first
            , delta:        (.db_sync.first - .nodes.first | fabs)
            }'

        sanity_check "$t" "$dir" '
          $analysis.slot_spans
          | (.db_sync.last - .nodes.last | fabs
            | . > $allowed.slot_spread_dbsync_last)
          ' '$analysis.slot_spans
          | { kind:         "slot-spread-dbsync-last"
            , dbsync_last:  .db_sync.last
            , nodes_last:   .nodes.last
            , delta:        (.db_sync.last - .nodes.last | fabs)
            }'
}

fetch_dbsync_results() {
        oprint "fetching the SQL extraction from explorer.."
        components=($(ls tools/*.sql | cut -d/ -f2))
        cat >'tools/db-analyser.sh' <<EOF
        set -e
        tag="\$1"

        files=()
        for query in ${components[*]}
        do files+=(\${query} \${query}.txt \${query}.csv)

           PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer \
             --file \${query} > \${query}.csv --csv
           PGPASSFILE=/var/lib/cexplorer/pgpass psql cexplorer cexplorer \
             --file \${query} > \${query}.txt
        done

        tar=${tag}.db-analysis.tar.xz
        tar cf \${tar} "\${files[@]}" --xz
        rm -f ${components[*]/%/.csv} ${components[*]/%/.txt}
EOF
        tar c 'tools/db-analyser.sh' "${components[@]/#/tools\/}" |
                nixops ssh explorer -- tar x --strip-components='1'
        nixops ssh explorer -- sh -c "ls; chmod +x 'db-analyser.sh';
                                      ./db-analyser.sh ${tag}" > 'logs/db-analysis.log'
        nixops scp --from explorer "${tag}.db-analysis.tar.xz" 'logs/db-analysis.tar.xz'
}
