{
  services.monitoring-services.applicationDashboards = ./grafana/cardano;
  services.monitoring-services.applicationRules = [
    {
      alert = "chain_quality_degraded";
      expr = "cardano_chain_quality_last_k__2160__blocks__ < 99";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Degraded Chain Quality over last 2160 blocks.";
        description = "{{$labels.alias}}: Degraded Chain Quality over last 2160 blocks (<99%).";
      };
    }
    {
      alert = "mempoolsize_tx_count_too_large";
      expr = "max_over_time(cardano_MemPoolSize[5m]) > 190";
      for = "1m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: MemPoolSize tx count is larger than expected.";
        description = "{{$labels.alias}}: When a node's MemPoolSize grows larger than the system can handle, transactions will be dropped. The actual thresholds for that in mainnet are unknown, but [based on benchmarks done beforehand](https://input-output-rnd.slack.com/archives/C2VJ41WDP/p1506563332000201) transactions started getting dropped when the MemPoolSize was ~200 txs.";
      };
    }
    {
      alert = "cardano_node_block_divergence";
      expr = "abs(max(cardano_byron_proxy_ChainDB_blockNum_int) - ignoring(alias,instance,job,role) group_right(instance) cardano_node_ChainDB_metrics_blockNum_int) > 2";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node block divergence with byron proxies detected for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-node block divergence with byron proxies detected for more than 5 minutes";
      };
    }
    {
      alert = "cardano_new_node_block_divergence";
      expr = "abs(max(cardano_node_ChainDB_metrics_blockNum_int) - ignoring(alias,instance,job,role) group_right(instance) cardano_node_ChainDB_metrics_blockNum_int) > 2";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-node block divergence detected for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-node block divergence detected for more than 5 minutes";
      };
    }
    {
      alert = "cardano_new_node_blockheight_unchanged";
      expr = "rate(cardano_node_ChainDB_metrics_blockNum_int[1m]) == 0";
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
      alert = "cardano_new_node_KES_expiration_metric_warning";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_Forge_metrics_remainingKESPeriods_int < (24 * 3600) + 1";
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
      alert = "cardano_new_node_KES_expiration_metric_critical";
      expr = "cardano_node_genesis_slotLength * cardano_node_genesis_slotsPerKESPeriod * on (alias) cardano_node_Forge_metrics_remainingKESPeriods_int < (4 * 3600) + 1";
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
      alert = "cardano_new_node_KES_expiration_decoded_warning";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_ChainDB_metrics_slotNum_int)) < (24 * 3600) + 1";
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
      alert = "cardano_new_node_KES_expiration_decoded_critical";
      expr = "(cardano_node_genesis_slotLength * (cardano_node_genesis_slotsPerKESPeriod " +
             "* ((cardano_node_decode_kesCreatedPeriod > -1) + cardano_node_genesis_maxKESEvolutions)) " +
             "- on(alias) (cardano_node_genesis_slotLength * on (alias) cardano_node_ChainDB_metrics_slotNum_int)) < (4 * 3600) + 1";
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
      alert = "byron_proxy_block_divergence";
      expr = "abs(max(cardano_total_main_blocks) - ignoring(alias,instance,job,role) group_right(instance) cardano_byron_proxy_ChainDB_blockNum_int) > 2";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: byron-proxy block divergence detected for more than 5 minutes";
        description = "{{$labels.alias}}: byron-proxy block divergence detected for more than 5 minutes";
      };
    }
    {
      alert = "explorer_node_db_block_divergence";
      expr = "abs(cardano_node_ChainDB_metrics_blockNum_int{alias=~\"explorer.*\"} - on() db_block_height{alias=~\"explorer.*\"}) > 5";
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
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) - count(count(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) by (alias)) > 120";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than 120 for more than 5 minutes.";
        description = "${region}: Average connection per nodes higher than 120 for more than 5 minutes. Adding new nodes to that region might soon be required.";
      };
    }
    {
      alert = "critical_tcp_connections_${region}";
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) - count(count(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) by (alias)) > 150";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than 150 for more than 15 minutes.";
        description = "${region}: Average connection per nodes higher than 150 for more than 15 minutes. Adding new nodes to that region IS required.";
      };
    }
    {
      alert = "high_egress_${region}";
      expr = "avg(rate(node_network_transmit_bytes_total{alias=~\"e-${regionLetter}-.*\",device!~\"lo\"}[20s]) * 8) > 150 * 1000 * 1000";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average egress throughput is higher than 150 Mbps for more than 5 minutes.";
        description = "${region}: Average egress throughput is higher than 150 Mbps for more than 5 minutes. Adding new nodes to that region might soon be required.";
      };
    }
    {
      alert = "critical_egress_${region}";
      expr = "avg(rate(node_network_transmit_bytes_total{alias=~\"e-${regionLetter}-.*\",device!~\"lo\"}[20s]) * 8) > 200 * 1000 * 1000";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average egress throughput is higher than 200 Mbps for more than 15 minutes.";
        description = "${region}: Average egress throughput is higher than 200 Mbps for more than 15 minutes. Adding new nodes to that region IS required.";
      };
    }])
  [{ region = "eu-central-1";   regionLetter = "a"; }
   { region = "ap-northeast-1"; regionLetter = "b"; }
   { region = "ap-southeast-1"; regionLetter = "c"; }
   { region = "us-east-2";      regionLetter = "d"; }
   { region = "us-west-1";      regionLetter = "e"; }
   { region = "eu-west-1";      regionLetter = "f"; }
  ]);
}
