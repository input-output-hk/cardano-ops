pkgs: with pkgs; with lib; with topology-lib {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 35;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 25;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 10;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 15;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 15;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 10;
    };
  };
let

  bftCoreNodes = regionalConnectGroupWith (reverseList stakingPoolNodes)
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

  stakingPoolNodes = regionalConnectGroupWith bftCoreNodes
  (twoHopsConnectNodes [
    (mkStakingPool "a" 1 "IOG1" { nodeId = 8; })

    (mkStakingPool "b" 1 "IOGP2" { nodeId = 28; })
    (mkStakingPool "c" 1 "IOGP3" { nodeId = 29; })
    (mkStakingPool "d" 1 "IOGP4" { nodeId = 30; })
    (mkStakingPool "e" 1 "IOGP5" { nodeId = 31; })
    (mkStakingPool "f" 1 "IOGP6" { nodeId = 32; })
    (mkStakingPool "a" 2 "IOGP7" { nodeId = 33; })
    (mkStakingPool "b" 2 "IOGP8" { nodeId = 34; })
    (mkStakingPool "c" 2 "IOGP9" { nodeId = 35; })
    (mkStakingPool "d" 2 "IOGP10" { nodeId = 36; })
    (mkStakingPool "e" 2 "IOGP11" { nodeId = 37; })
    (mkStakingPool "f" 2 "IOGP12" { nodeId = 38; })
    (mkStakingPool "a" 3 "IOGP13" { nodeId = 39; })
    (mkStakingPool "b" 3 "IOGP14" { nodeId = 40; })
    (mkStakingPool "c" 3 "IOGP15" { nodeId = 41; })
    (mkStakingPool "d" 3 "IOGP16" { nodeId = 42; })
    (mkStakingPool "e" 3 "IOGP17" { nodeId = 43; })
    (mkStakingPool "f" 3 "IOGP18" { nodeId = 44; })
    (mkStakingPool "a" 4 "IOGP19" { nodeId = 45; })
    (mkStakingPool "b" 4 "IOGP20" { nodeId = 46; })
    (mkStakingPool "c" 4 "IOGP21" { nodeId = 47; })
    (mkStakingPool "d" 4 "IOGP22" { nodeId = 48; })
    (mkStakingPool "e" 4 "IOGP23" { nodeId = 49; })
    (mkStakingPool "f" 4 "IOGP24" { nodeId = 50; })
    (mkStakingPool "a" 5 "IOGP25" { nodeId = 51; })
    (mkStakingPool "b" 5 "IOGP26" { nodeId = 52; })
    (mkStakingPool "c" 5 "IOGP27" { nodeId = 53; })
    (mkStakingPool "d" 5 "IOGP28" { nodeId = 54; })
    (mkStakingPool "e" 5 "IOGP29" { nodeId = 55; })
    (mkStakingPool "f" 5 "IOGP30" { nodeId = 56; })
    (mkStakingPool "a" 6 "IOGP31" { nodeId = 57; })
    (mkStakingPool "b" 6 "IOGP32" { nodeId = 58; })
    (mkStakingPool "c" 6 "IOGP33" { nodeId = 59; })
    (mkStakingPool "d" 6 "LEO1"   { nodeId = 60; })
  ]);

  coreNodes = map (withAutoRestartEvery 6)
    (bftCoreNodes ++ stakingPoolNodes);

  relayNodes = map (composeAll [
    (withAutoRestartEvery 6)
    (forNodes {
      services.cardano-node.extraNodeConfig = {
        TraceMempool = true;
      };
    } [ "rel-a-1" "rel-b-1" "rel-c-1" "rel-d-1" "rel-e-1" "rel-f-1" ])
  ]) (mkRelayTopology {
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

  smash = {
    #TODO: use nginx caching directive instead of upscaling:
    deployment.ec2.instanceType = lib.mkForce "t3a.2xlarge";
  };

  metadata = {
    node = {
      org = "CF";
      roles.isPublicSsh = true;
    };
  };
}
