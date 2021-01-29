pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   /* Europe (Frankfurt)       */ };
    b = { name = "us-east-2";      /* US East (Ohio)           */ };
    c = { name = "ap-southeast-1"; /* Asia Pacific (Singapore) */ };
  };

  bftCoreNodes = let
    mkBftCoreNode = r: idx: attrs: (mkBftCoreNodeForRegions regions r idx attrs) // {
      org = "IOHK";
      producers = [{
        addr = globals.relaysNew;
        port = globals.cardanoNodePort;
        valency = 3;
      }];
    };
  in regionalConnectGroupWith (reverseList stakingPoolNodes)
  (fullyConnectNodes [
    # OBFT centralized nodes recovery nodes
    (mkBftCoreNode "a" 1 {
      nodeId = 1;
    })
    (mkBftCoreNode "b" 1 {
      nodeId = 2;
    })
    (mkBftCoreNode "c" 1 {
      nodeId = 3;
    })
  ]);

  stakingPoolNodes = let
    mkStakingPool = mkStakingPoolForRegions regions;
  in regionalConnectGroupWith bftCoreNodes
  (fullyConnectNodes [
    (mkStakingPool "a" 1 "IOHK1" { nodeId = 4; })
  ]);

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
  };

in {

  inherit coreNodes relayNodes;

  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = false;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 10000000000;
      useByronWallet = false;
    };
  };

  explorer = {
    services.nginx.virtualHosts.${globals.explorerHostName}.locations."/p" = lib.mkIf (__pathExists ../static/pool-metadata) {
      root = ../static/pool-metadata;
    };
  };

}
