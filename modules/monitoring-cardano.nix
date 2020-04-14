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
      expr = "abs(max(cardano_total_main_blocks) - ignoring(alias,instance,job,role) group_right(instance) cardano_node_ChainDB_metrics_blockNum_int) > 2";
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
  ] ++ (builtins.concatMap ({region, regionLetter}: [
    {
      alert = "high_tcp_connections_${region}";
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) - count(count(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) by (alias)) > 60";
      for = "5m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than 60 for more than 5 minutes.";
        description = "${region}: Average connection per nodes higher than 60 for more than 5 minutes. Adding new nodes to that region might soon be required.";
      };
    }
    {
      alert = "critical_tcp_connections_${region}";
      expr = "avg(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) - count(count(node_netstat_Tcp_CurrEstab{alias=~\"e-${regionLetter}-.*\"}) by (alias)) > 80";
      for = "15m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "${region}: Average connection per nodes higher than 80 for more than 15 minutes.";
        description = "${region}: Average connection per nodes higher than 80 for more than 15 minutes. Adding new nodes to that region IS required.";
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
  ]);
}
