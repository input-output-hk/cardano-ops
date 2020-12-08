pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 65;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 40;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 20;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 25;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 25;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 15;
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
      org = "Emurgo";
      nodeId = 3;
    })
    (mkBftCoreNode "d" 1 {
      org = "Emurgo";
      nodeId = 4;
    })
    (mkBftCoreNode "e" 1 {
      org = "CF";
      nodeId = 5;
    })
    (mkBftCoreNode "f" 1 {
      org = "CF";
      nodeId = 6;
    })
    (mkBftCoreNode "a" 2 {
      org = "IOHK";
      nodeId = 7;
    })
  ]);

  stakingPoolNodes = let
    mkStakingPool = mkStakingPoolForRegions regions;
  in regionalConnectGroupWith bftCoreNodes
  (oneHopConnectNodes [
    (mkStakingPool "a" 1 "IOG1" { nodeId = 8; })
    (mkStakingPool "b" 1 "IOG2" { nodeId = 9; })
    (mkStakingPool "c" 1 "IOG3" { nodeId = 10; })
    (mkStakingPool "d" 1 "IOG4" { nodeId = 11; })
    (mkStakingPool "e" 1 "IOG5" { nodeId = 12; })
    (mkStakingPool "f" 1 "IOG6" { nodeId = 13; })
    (mkStakingPool "a" 2 "IOG7" { nodeId = 14; })
    (mkStakingPool "b" 2 "IOG8" { nodeId = 15; })
    (mkStakingPool "c" 2 "IOG9" { nodeId = 16; })
    (mkStakingPool "d" 2 "IOG10" { nodeId = 17; })
    (mkStakingPool "e" 2 "IOG11" { nodeId = 18; })
    (mkStakingPool "f" 2 "IOG12" { nodeId = 19; })
    (mkStakingPool "a" 3 "IOG13" { nodeId = 20; })
    (mkStakingPool "b" 3 "IOG14" { nodeId = 21; })
    (mkStakingPool "c" 3 "IOG15" { nodeId = 22; })
    (mkStakingPool "d" 3 "IOG16" { nodeId = 23; })
    (mkStakingPool "e" 3 "IOG17" { nodeId = 24; })
    (mkStakingPool "f" 3 "IOG18" { nodeId = 25; })
    (mkStakingPool "a" 4 "IOG19" { nodeId = 26; })
    (mkStakingPool "b" 4 "IOG20" { nodeId = 27; })
  ]);

  coreNodes = map (withAutoRestartEvery 6)
    (bftCoreNodes ++ stakingPoolNodes);

  relayNodes = map (withAutoRestartEvery 6) (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
    maxProducersPerNode = 20;
    maxInRegionPeers = 5;
  });

in {

  inherit coreNodes relayNodes;

  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };
}
