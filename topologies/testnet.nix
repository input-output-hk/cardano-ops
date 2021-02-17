pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 6;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 4;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 3;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 3;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 4;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 3;
    };
  };

  bftCoreNodes = let
    mkBftCoreNode = mkBftCoreNodeForRegions regions;
  in regionalConnectGroupWith (reverseList stakingPoolNodes)
  (fullyConnectNodes [
    # OBFT centralized nodes recovery nodes
    (mkBftCoreNode "a" 1 {
      org = "IOHK";
      nodeId = 1;
    })
    (mkBftCoreNode "b" 1 {
      org = "IOHK";
      nodeId = 2;
    })
    (mkBftCoreNode "c" 1 {
      org = "IOHK";
      nodeId = 3;
    })
    (mkBftCoreNode "d" 1 {
      org = "IOHK";
      nodeId = 4;
    })
    (mkBftCoreNode "e" 1 {
      org = "IOHK";
      nodeId = 5;
    })
    (mkBftCoreNode "f" 1 {
      org = "IOHK";
      nodeId = 6;
    })
    (mkBftCoreNode "a" 2 {
      org = "IOHK";
      nodeId = 7;
    })
  ]);

  stakingPoolNodes = let
    mkStakingPool = mkStakingPoolForRegions regions;
  in regionalConnectGroupWith bftCoreNodes (fullyConnectNodes [
    (mkStakingPool "a" 1 "" { nodeId = 8; })
    (mkStakingPool "b" 1 "" { nodeId = 9; })
    (mkStakingPool "c" 1 "" { nodeId = 10; })
    (mkStakingPool "d" 1 "" { nodeId = 11; })
    (mkStakingPool "e" 1 "" { nodeId = 12; })
    (mkStakingPool "f" 1 "" { nodeId = 13; })
    (mkStakingPool "a" 2 "" { nodeId = 14; })
  ]);

  coreNodes = map (withAutoRestartEvery 6) (bftCoreNodes ++ stakingPoolNodes);

  relayNodes = map (withAutoRestartEvery 6) (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
    maxProducersPerNode = 20;
    maxInRegionPeers = 5;
  });

in {
  inherit coreNodes relayNodes;

  services.monitoring-services.publicGrafana = true;

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = true;
      anonymousAccessAssets = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsAnonymousAssets = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      assetsToGiveAnonymous = 2;
      lovelacesToGiveApiKeyAuth = 1000000000000;
      useByronWallet = false;
      faucetFrontendUrl = "https://developers.cardano.org/en/testnets/cardano/tools/faucet/";
    };
  };
  explorer = {
    services.nginx.virtualHosts.${globals.explorerHostName}.locations."/p" = lib.mkIf (__pathExists ../static/pool-metadata) {
      root = ../static/pool-metadata;
    };
  };
}
