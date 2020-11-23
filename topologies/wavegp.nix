pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   /* Europe (Frankfurt)       */  };
    d = { name = "eu-west-2";      /* Europe (London)          */  };
  };

  mkStkNode = r: idx: ticker: attrs: rec {
    name = "stk-${r}-${toString idx}-${ticker}";
    region = regions.${r}.name;
    org = "WAVE";
    stakePool = true;
  } // attrs;

  mkRelNode = r: idx: attrs: rec {
    name = "rel-${r}-${toString idx}";
    region = regions.${r}.name;
    org = "WAVE";
    producers = [(
      envRegionalRelaysProducer region 3
    )];
  } // attrs;

  nodes = map (withAutoRestartEvery 6)
    (fullyConnectNodes [
      (mkStkNode "a" 1 "WAV1" { nodeId = 1; })
      (mkStkNode "d" 1 "CFD1" { nodeId = 2; })
      (mkRelNode "a" 1 { nodeId = 3; })
      (mkRelNode "d" 1 { nodeId = 4; })
      (mkRelNode "a" 2 { nodeId = 5; })
      (mkRelNode "d" 2 { nodeId = 6; })
    ]);

  relayNodes = filter (n: !(n.stakePool or false)) nodes;

  coreNodes = filter (n: n.stakePool or false) nodes;

in {

  inherit coreNodes relayNodes;

  monitoring = {
    services.monitoring-services.publicGrafana = false;
    org = "WAVE";

    services.nginx.virtualHosts."monitoring.${globals.dnsZone}".locations."/p" = {
      root = ../static/pool-metadata;
    };
  };

}
