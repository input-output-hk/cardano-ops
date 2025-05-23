pkgs: { ... }:
with pkgs;
let

  chainDensityLow = globals.alertChainDensityLow;
  tcpHigh = toString globals.alertTcpHigh;
  tcpCrit = toString globals.alertTcpCrit;
  MbpsHigh = toString globals.alertMbpsHigh;
  MbpsCrit = toString globals.alertMbpsCrit;
  highBlockUtilization = toString globals.alertHighBlockUtilization;
  slotLength = globals.environmentVariables.SLOT_LENGTH;
in {
  imports = [ ./ssh.nix ];

  services.monitoring-services.logging = false;
  services.monitoring-services.applicationDashboards = ./grafana/cardano;
  services.monitoring-services.applicationRules = [
    {
      alert = "cardano_node_elevated_restarts";
      expr = ''round(increase(node_systemd_unit_state{name=~"cardano-node(-[0-9]+)?.service", state="active"}[1h])) > 1'';
      for = "5m";
      labels.severity = "page";
      annotations = {
        summary = "{{$labels.instance}}: cardano-node has experienced multiple restarts in the past hour.";
        description = "{{$labels.instance}}: cardano-node has restarted {{ printf \"%.0f\" $value }} times in the past hour.";
      };
    }
    {
      alert = "node_oom_detected";
      expr = ''increase(node_vmstat_oom_kill[1h]) > 0'';
      for = "5m";
      labels.severity = "page";
      annotations = {
        summary = "The OOM killer has been active in the past hour.";
        description = "{{ $labels.alias }} has had {{ printf \"%.0f\" $value }} OOM killing(s) in the past hour. Please investigate.";
      };
    }
    {
      alert = "coredump_detected";
      expr = ''cardano_coredumps_last_hour > 0'';
      for = "5m";
      labels.severity = "page";
      annotations = {
        summary = "Coredumps have been detected in the past hour.";
        description = "{{ $labels.instance }} has had {{ printf \"%.0f\" $value }} coredump(s) in the past hour. Please investigate.";
      };
    }
    {
      alert = "cardano_graphql_down";
      expr = ''up{alias="cardano-graphql-exporter"} == 0'';
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Cardano-graphql is down.";
        description = "{{$labels.alias}} cardano-graphql has been down for more than 15 minutes.";
      };
    }
    {
      alert = "http_high_internal_error_rate_explorer";
      expr = ''
        rate(nginx_vts_server_requests_total{code="5xx",alias=~"explorer-.*"}[5m]) * 50 > on(alias, host) rate(nginx_vts_server_requests_total{code="2xx",alias=~"explorer-.*"}[5m])'';
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary =
          "{{$labels.alias}}: High explorer http internal error (code 5xx) rate";
        description =
          "{{$labels.alias}}  number of correctly served requests is less than 50 times the number of requests aborted due to an internal server error for more than 15 minutes";
      };
    }
    {
      alert = "blackbox_probe_down";
      expr = "probe_success == 0";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.job}}: Blackbox probe is down for {{$labels.instance}}.";
        description = "{{$labels.job}}: Blackbox probe has been down for at least 15 minutes for {{$labels.instance}}.";
      };
    }
    {
      alert = "High cardano ping latency";
      expr = "avg_over_time(cardano_ping_latency_ms[5m]) > 250";
      for = "45m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary =  "{{$labels.alias}}: Cardano average ping latency over 5 minutes has been above 250 milliseconds for the last 45 minutes";
        description = "{{$labels.alias}}: Cardano average ping latency over 5 minutes has been above 250 milliseconds for the last 45 minutes.";
      };
    }
    {
      alert = "chain_quality_degraded";
      expr = "quantile(0.2, (cardano_node_metrics_density_real / on(alias) cardano_node_genesis_activeSlotsCoeff * 100)) < ${chainDensityLow}";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "Degraded Chain Density: more than 20% of nodes have low chain density (<${chainDensityLow}%).";
        description = "Degraded Chain Density: more than 20% of nodes have low chain density (<${chainDensityLow}%).";
      };
    }
    {
      alert = "blocks adoption delay too high";
      expr = "avg(quantile_over_time(0.95, cardano_node_metrics_blockadoption_forgeDelay_real[6h])) >= 4.5";
      for = "1m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "Blocks adoption delay have been above 4.5s for more than 5% of blocks";
        description = "Node average of blocks adoption delay have been above 4.5s for more than 5% of blocks for more than 6 hours";
      };
    }
    {
      alert = "blocks_utilization_too_high";
      expr = "100 * avg(avg_over_time(cardano_node_metrics_blockfetchclient_blocksize[6h]) / on(alias) (cardano_node_protocol_maxBlockBodySize + cardano_node_protocol_maxBlockHeaderSize)) > ${highBlockUtilization}";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "Blocks utilization above ${highBlockUtilization}% - follow process in description.";
        description = "Blocks utilization has been above ${highBlockUtilization}% on average for more than 6h. Follow process at https://docs.google.com/document/d/1H42XpVp5YKUfKTcfyV_YJP5nM2N5D9eU_0MvFbXXp0E";
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
      for = "10m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node blockheight unchanged for more than 10 minutes";
        description = "{{$labels.alias}}: cardano-node blockheight unchanged for more than 10 minutes at a 1 minute rate resolution";
      };
    }
    {
      alert = "cardano_new_node_forge_not_adopted_error";
      expr = "increase(cardano_node_metrics_Forge_didnt_adopt_int[1h]) > 5";
      for = "1m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node is failing to adopt a significant amount of recent forged blocks";
        description = ''
          {{$labels.alias}}: cardano-node failed to adopt more than 5 forged blocks in the past hour.
          A restart of node on the affected machine(s) may be required.'';
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
