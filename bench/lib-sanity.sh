#!/usr/bin/env bash
# shellcheck disable=1091,2016

sanity_check_list=()

sanity_check_list+=(sanity_check_start_log_spread)
sanity_check_start_log_spread() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $analysis.logs
          | map
            ( (.earliest - $meta.timestamp | fabs)
              as $delta
            | select ($delta > $allowed.start_log_spread_s)
            | . +
              { delta: $delta
              , start: $meta.timestamp })
          ' '.
          | map
            ({ kind:      "start-log-spread"
             } + .)
          | .[]'
}
sanity_check_list+=(sanity_check_last_log_spread)
sanity_check_last_log_spread() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $analysis.logs
          | map  ## Generator always finishes a bit early, and
                 ##  we have it analysed to death by other means..
            (select (.name != "generator"))
          | map
            ( (.latest - $analysis.final_log_timestamp | fabs)
              as $delta
            | select ($delta > $allowed.last_log_spread_s)
            | . +
              { delta: $delta
              , final_log_timestamp: $analysis.final_log_timestamp })
          ' '.
          | map
            ({ kind:      "latest-log-spread"
             } + .)
          | .[]'
}
sanity_check_list+=(sanity_check_not_even_started)
sanity_check_not_even_started() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $blocks
          | length == 0
          ' '.
          | { kind:       "blockchain-not-even-started"
            }' --slurpfile blocks "$dir"/analysis/explorer.MsgBlock.json
}
sanity_check_list+=(sanity_check_silence_since_last_block)
sanity_check_silence_since_last_block() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $blocks[-1] // { timestamp: $analysis.first_node_log_timestamp }
          | ($analysis.final_node_log_timestamp - .timestamp)
            as $delta
          | if $delta >= $allowed.silence_since_last_block_s
            then $delta else empty end
          ' '.
          | { kind:       "blockchain-stopped"
            , silence_since_last_block_s: .
            , allowance:  $allowed.silence_since_last_block_s
            }' --slurpfile blocks "$dir"/analysis/explorer.MsgBlock.json
}
sanity_check_list+=(sanity_check_no_txs_in_blocks)
sanity_check_no_txs_in_blocks() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $txstats.tx_seen_in_blocks == 0' '
          { kind:         "no-txs-in-blocks"
          }'
}
sanity_check_list+=(sanity_check_announced_less_txs_than_specified)
sanity_check_announced_less_txs_than_specified() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          ## Guard against old logs, where tx_annced is 0:
          $txstats.tx_annced >= $txstats.tx_sent and
          $prof.generator.tx_count > $txstats.tx_annced' '
          { kind:         "announced-less-txs-than-specified"
          , required:     $prof.generator.tx_count
          , sent:         $txstats.tx_sent
          }'
}
sanity_check_list+=(sanity_check_sent_less_txs_than_specified)
sanity_check_sent_less_txs_than_specified() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $prof.generator.tx_count > $txstats.tx_sent' '
          { kind:         "sent-less-txs-than-specified"
          , required:     $prof.generator.tx_count
          , sent:         $txstats.tx_sent
          }'
}
sanity_check_list+=(sanity_check_tx_loss_over_threshold)
sanity_check_tx_loss_over_threshold() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
          $txstats.tx_sent * (1.0 - $allowed.tx_loss_ratio)
            > $txstats.tx_seen_in_blocks' '
          { kind:         "txs-loss-over-threshold"
          , sent:         $txstats.tx_sent
          , threshold:    ($txstats.tx_sent * (1.0 - $allowed.tx_loss_ratio))
          , received:     $txstats.tx_seen_in_blocks
          }'
}
sanity_check_list+=(sanity_check_chain_density)
sanity_check_chain_density() {
        local dir=$1 t=${2:-${default_tolerances}}
        sanity_check "$t" "$dir" '
            ($blocks | length)
              as $block_count
          | ($analysis.final_node_log_timestamp
             - $analysis.first_node_log_timestamp)
              as $cluster_lifetime_s
          | ($cluster_lifetime_s * 1000 / $genesis.slot_duration | floor)
              as $cluster_lifetime_slots
          | ($block_count / ($cluster_lifetime_slots))
              as $chain_density
          | ($cluster_lifetime_slots - $block_count)
              as $missed_slots
          | if $chain_density < $allowed.minimum_chain_density or
               $missed_slots > $allowed.maximum_missed_slots
            then { lifetime_s:     $cluster_lifetime_s
                 , lifetime_slots: $cluster_lifetime_slots
                 , block_count:    $block_count
                 , missed_slots:   $missed_slots
                 , chain_density:  $chain_density
                 } else empty end' '
          { kind:                 "insufficient_overall_chain_density"
          , lifetime_s:           .lifetime_s
          , lifetime_slots:       .lifetime_slots
          , block_count:          .block_count
          , missed_slots:         .missed_slots
          , chain_density:        .chain_density
          }' --slurpfile blocks "$dir"/analysis/explorer.MsgBlock.json
}
# sanity_check_list+=(sanity_check_)
# sanity_check_() {
#         local t=$1 dir=$2
# }

default_tolerances='
{ "tx_loss_ratio":                  0.0
, "start_log_spread_s":             60
, "last_log_spread_s":              60
, "silence_since_last_block_s":     40
, "cluster_startup_overhead_s":     60
, "minimum_chain_density":          0.9
, "maximum_missed_slots":           5
}'

sanity_check_run() {
        local dir=${1:-.} metafile meta prof tolerances t

        for check in ${sanity_check_list[*]}
        do $check "$dir" "${default_tolerances}"
        done | jq --slurp '
          if length != 0
          then . +
            [{ kind:      "tolerances" }
             + $tolerances] else . end
            ' --argjson tolerances "$default_tolerances"
}

sanity_check() {
        local tolerances=$1 dir=$2 test=$3 err=$4; shift 4
        sanity_checker "$tolerances" "$dir" \
          " ($test)"' as $test
          | if $test != {} and $test != [] and $test != "" and $test
            then ($test | '"$err"') else empty end
          ' "$@"
}

sanity_checker() {
        local tolerances=$1 dir=$2 expr=$3; shift 3

        jq ' $meta[0].meta         as $meta
           | $analysis[0]          as $analysis
           | $txstats[0]           as $txstats
           | ($meta.profile_content
              ## TODO:  backward compat
              // $meta.generator_params)
              as $prof
           | ($prof.genesis
              ## TODO:  backward compat
              // $prof.genesis_params)
              as $genesis
           | $prof.generator       as $generator
           | '"$expr"'
           ' --slurpfile meta     "$dir/meta.json" \
             --slurpfile analysis "$dir/analysis.json" \
             --slurpfile txstats  "$dir/analysis/tx-stats.json" \
             --argjson   allowed  "$tolerances" \
             "$@" <<<0
}
