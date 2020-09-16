pkgs: { ... }:
with pkgs;
let

  chainDensityLow = globals.alertChainDensityLow;
  memPoolHigh = globals.alertMemPoolHigh;
  tcpHigh = globals.alertTcpHigh;
  tcpCrit = globals.alertTcpCrit;
  MbpsHigh = globals.alertMbpsHigh;
  MbpsCrit = globals.alertMbpsCrit;
in {
  services.monitoring-services.applicationDashboards = ./grafana/cardano;
  services.monitoring-services.applicationRules = [
    {
      alert = "chain_quality_degraded";
      expr = "(cardano_node_ChainDB_metrics_density_real{alias!~\"bft-dr-.*|rel-dr-.*\"} / on(alias) cardano_node_genesis_activeSlotsCoeff * 100) < ${chainDensityLow}";
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
      alert = "shadow_chain_quality_degraded";
      expr = "(cardano_node_ChainDB_metrics_density_real{alias=~\"bft-dr-.*|rel-dr-.*\"} / on(alias) cardano_node_genesis_activeSlotsCoeff * 100) < 90";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Shadow Cluster Degraded Chain Density (<90%).";
        description = "{{$labels.alias}}: Shadow Cluster Degraded Chain Density (<90%).";
      };
    }
    {
      alert = "mempoolsize_tx_count_too_large";
      expr = "max_over_time(cardano_node_metrics_txsInMempool_int[5m]) > ${memPoolHigh}";
      for = "1m";
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
      expr = "abs(max(cardano_node_ChainDB_metrics_blockNum_int{alias!~\"bft-dr.*|rel-dr.*\"}) - ignoring(alias,instance,job,role) group_right(instance) cardano_node_ChainDB_metrics_blockNum_int{alias!~\"bft-dr.*|rel-dr.*\"}) > 2";
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
      alert = "cardano_shadow_node_block_divergence";
      expr = "abs(max(cardano_node_ChainDB_metrics_blockNum_int{alias=~\"bft-dr.*|rel-dr.*\"}) - ignoring(alias,instance,job,role) group_right(instance) cardano_node_ChainDB_metrics_blockNum_int{alias=~\"bft-dr.*|rel-dr.*\"}) > 2";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: cardano-shadow-node block divergence detected for more than 5 minutes";
        description = "{{$labels.alias}}: cardano-shadow-node block divergence detected for more than 5 minutes";
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
