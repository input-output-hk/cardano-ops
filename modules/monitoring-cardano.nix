pkgs: { ... }:
with pkgs;
let

  chainDensityLow = globals.alertChainDensityLow;
  memPoolHigh = globals.alertMemPoolHigh;
  tcpHigh = toString globals.alertTcpHigh;
  tcpCrit = toString globals.alertTcpCrit;
  MbpsHigh = toString globals.alertMbpsHigh;
  MbpsCrit = toString globals.alertMbpsCrit;
  slotLength = globals.environmentVariables.SLOT_LENGTH;
in {
  services.monitoring-services.logging = false;
  services.monitoring-services.applicationDashboards = ./grafana/cardano;
  services.monitoring-services.applicationRules = [
    {
      alert = "blackbox_probe_down";
      expr = "probe_success == 0";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.job}}: Blackbox probe is down for {{$labels.instance}}.";
        description = "{{$labels.job}}: Blackbox probe has been down for at least 5 minutes for {{$labels.instance}}.";
      };
    }
    {
      alert = "High cardano ping latency";
      expr = "quantile_over_time(0.95, cardano_ping_latency_ms[1h:1m]) > 50";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Cardano ping P95 latency has been above 50 milliseconds";
        description = "{{$labels.alias}}: Cardano ping P95 latency has been above 50 milliseconds for the last 15 minutes.";
      };
    }
    {
      alert = "chain_quality_degraded";
      expr = "(cardano_node_metrics_density_real / on(alias) cardano_node_genesis_activeSlotsCoeff * 100) < ${chainDensityLow}";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Degraded Chain Density (<${chainDensityLow}%).";
        description = "{{$labels.alias}}: Degraded Chain Density (<${chainDensityLow}%).";
      };
    }
    {
      alert = "mempoolsize_tx_count_too_large";
      expr = "max_over_time(cardano_node_metrics_txsInMempool_int[5m]) > ${memPoolHigh}";
      for = "10m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: MemPoolSize tx count is larger than expected (>${memPoolHigh}).";
        description = "{{$labels.alias}}: When a node's MemPoolSize grows larger than the system can handle, transactions will be dropped. The actual thresholds for that in mainnet are unknown, but [based on benchmarks done beforehand](https://input-output-rnd.slack.com/archives/C2VJ41WDP/p1506563332000201) transactions started getting dropped when the MemPoolSize was ~200 txs.";
      };
    }
    {
      alert = "cardano_new_node_block_divergence";
      expr = "((abs(max(cardano_node_metrics_blockNum_int) - ignoring(alias, instance, job, role) group_right(instance) cardano_node_metrics_blockNum_int) > bool 2) - (abs(max(cardano_node_metrics_slotNum_int) - ignoring(alias, instance, job, role) group_right(instance) cardano_node_metrics_slotNum_int) < bool 60)) == 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node block divergence detected for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-node block divergence of more than 2 blocks and 60 seconds lag detected for more than 5 minutes";
      };
    }
    {
      alert = "cardano_new_node_blockheight_unchanged";
      expr = "rate(cardano_node_metrics_blockNum_int[1m]) == 0";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node blockheight unchanged for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-node blockheight unchanged for more than 5 minutes at a 1 minute rate resolution";
      };
    }
    {
      alert = "cardano_new_node_forge_not_adopted_error";
      expr = "cardano_node_metrics_Forge_didnt_adopt_int > 0";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node failed to adopt forged block";
        description = "{{$labels.alias}}: restart of node is needed to resolve this alert";
      };
    }
    {
      alert = "too many slot leadership checks missed";
      expr = "rate(cardano_node_metrics_slotsMissedNum_int[5m]) * ${slotLength} > 0.5";
      for = "2m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: block producing node is failing to check for slot leadership for more than half of the slots.";
        description = "{{$labels.alias}}: block producing node is failing to check for slot leadership for more than half of the slots for more than 2 min.";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_metric_10day_notice";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_metrics_remainingKESPeriods_int < (10 * 24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration notice: less than 10 days until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration notice: less than 10 days until KES expiration; calculated from node metrics";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_metric_5day_notice";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_metrics_remainingKESPeriods_int < (5 * 24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration notice: less than 5 days until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration notice: less than 5 days until KES expiration; calculated from node metrics";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_metric_1day_warning";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_metrics_remainingKESPeriods_int < (24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration warning: less than 1 day until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration warning: less than 1 day until KES expiration; calculated from node metrics";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_metric_4hour_critical";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_metrics_remainingKESPeriods_int < (4 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration warning: less than 4 hours until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration warning: less than 4 hours until KES expiration; calculated from node metrics";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_decoded_10day_notice";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_metrics_slotNum_int)) < (10 * 24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration notice: less than 10 days until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration notice: less than 10 days until KES expiration; calculated from opcert decoding";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_decoded_5day_notice";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_metrics_slotNum_int)) < (5 * 24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration notice: less than 5 days until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration notice: less than 5 days until KES expiration; calculated from opcert decoding";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_decoded_1day_warning";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_metrics_slotNum_int)) < (24 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration warning: less than 1 day until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration warning: less than 1 day until KES expiration; calculated from opcert decoding";
      };
    }
    {
      alert = "cardano_new_node_KES_expiration_decoded_4hour_critical";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_metrics_slotNum_int)) < (4 * 3600) + 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node KES expiration warning: less than 4 hours until KES expiration";
        description = "{{$labels.alias}}: cardano-node KES expiration warning: less than 4 hours until KES expiration; calculated from opcert decoding";
      };
    }
    {
      alert = "explorer_node_db_block_divergence";
      expr = "abs(cardano_node_metrics_blockNum_int{alias=~\"explorer.*\"} - on() db_block_height{alias=~\"explorer.*\"}) > 5";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node db block divergence on explorer detected for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-node db block divergence detected on explorer of more than 5 blocks for more than 5 minutes";
      };
    }
    {
      alert = "faucet_value_zero_available";
      expr = "cardano_faucet_metrics_value_available{alias=~\".*faucet.*\"} == bool 0 == 1";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-faucet has zero balance available for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-faucet has zero balance available for more than 5 minutes";
      };
    }
  ] ++ (builtins.concatMap ({region, regionLetter}: [
    {
      alert = "high_tcp_connections_${region}";
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"rel-${regionLetter}-.*\"}) " +
             "- count(count(node_netstat_Tcp_CurrEstab{alias=~\"rel-${regionLetter}-.*\"}) by (alias)) > ${tcpHigh}";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than ${tcpHigh} for more than 5 minutes.";
        description = "${region}: Average connection per nodes higher than ${tcpHigh} for more than 5 minutes. Adding new nodes to that region might soon be required.";
      };
    }
    {
      alert = "critical_tcp_connections_${region}";
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"rel-${regionLetter}-.*\"}) " +
             "- count(count(node_netstat_Tcp_CurrEstab{alias=~\"rel-${regionLetter}-.*\"}) by (alias)) > ${tcpCrit}";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than ${tcpCrit} for more than 15 minutes.";
        description = "${region}: Average connection per nodes higher than ${tcpCrit} for more than 15 minutes. Adding new nodes to that region IS required.";
      };
    }
    {
      alert = "high_egress_${region}";
      expr = "avg(rate(node_network_transmit_bytes_total{alias=~\"rel-${regionLetter}-.*\",device!~\"lo\"}[20s]) * 8) > ${MbpsHigh} * 1000 * 1000";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average egress throughput is higher than ${MbpsHigh} Mbps for more than 5 minutes.";
        description = "${region}: Average egress throughput is higher than ${MbpsHigh} Mbps for more than 5 minutes. Adding new nodes to that region might soon be required.";
      };
    }
    {
      alert = "critical_egress_${region}";
      expr = "avg(rate(node_network_transmit_bytes_total{alias=~\"rel-${regionLetter}-.*\",device!~\"lo\"}[20s]) * 8) > ${MbpsCrit} * 1000 * 1000";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average egress throughput is higher than ${MbpsCrit} Mbps for more than 15 minutes.";
        description = "${region}: Average egress throughput is higher than ${MbpsCrit} Mbps for more than 15 minutes. Adding new nodes to that region IS required.";
      };
    }])
  [{ region = "eu-central-1";   regionLetter = "a"; }
   { region = "us-east-2";      regionLetter = "b"; }
   { region = "ap-southeast-1"; regionLetter = "c"; }
   { region = "eu-west-2";      regionLetter = "d"; }
   { region = "us-west-1";      regionLetter = "e"; }
   { region = "ap-northeast-1"; regionLetter = "f"; }
  ]);
}
