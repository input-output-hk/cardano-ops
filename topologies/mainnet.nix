pkgs: with pkgs; with lib; with topology-lib;
let

  withAutoRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 *
        60 * 60 + 60 * (def.nodeId or 0);
    };
  } def;

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 35;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 25;
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
      minRelays = 10;
    };
  };

  bftCoreNodes = let
    mkBftCoreNode = r: idx: attrs:
      rec {
        name = "bft-${r}-${toString idx}";
        region = regions.${r}.name;
        producers = # a share of the staking pool nodes:
          map (s: s.name) (filter (s: mod (s.nodeId - 8) 7 == (attrs.nodeId - 1)) stakingPoolNodes)
          ++ # some nearby relays:
          [{
            addr = relayGroupForRegion region;
            port = globals.cardanoNodePort;
            valency = 3;
          }];
      } // attrs;
  in withinOneHop [
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
  ];

  stakingPoolNodes =
    let
      bftCoreNodesInterval = (length stakingPoolNodes) / (length bftCoreNodes);
      mkStakingPool = r: idx: ticker: attrs: rec {
        name = "stk-${r}-${toString idx}-${ticker}";
        region = regions.${r}.name;
        producers = # a share of the bft core nodes:
          optional (mod (attrs.nodeId - 8) bftCoreNodesInterval == 0 && (attrs.nodeId - 8) / bftCoreNodesInterval < (length bftCoreNodes))
            (elemAt bftCoreNodes ((attrs.nodeId - 8) / bftCoreNodesInterval)).name
          ++ # some nearby relays:
          [{
            addr = relayGroupForRegion region;
            port = globals.cardanoNodePort;
            valency = 3;
          }];
        org = "IOHK";
      } // attrs;
  in withinOneHop [
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
  ];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
  });

  oldCoreNodes =
    let mkCoreNode = r: idx: attrs:
      rec {
        name = "c-${r}-${toString idx}";
        producers = filter (n: n != name) (map (c: c.name) oldCoreNodes)
          ++ [{
            addr = relayGroupForRegion attrs.region;
            port = globals.cardanoNodePort;
            valency = 3;
          }];
      } // attrs;
    in [
      # OBFT centralized nodes nodes
      (mkCoreNode "a" 1 {
        org = "IOHK";
        region = "eu-central-1";
        nodeId = 1;
      })
      (mkCoreNode "a" 2 {
        org = "IOHK";
        region = "eu-central-1";
        nodeId = 2;
      })
      (mkCoreNode "b" 1 {
        org = "Emurgo";
        region = "ap-northeast-1";
        nodeId = 3;
      })
      (mkCoreNode "b" 2 {
        org = "Emurgo";
        region = "ap-northeast-1";
        nodeId = 4;
      })
      (mkCoreNode "c" 1 {
        org = "CF";
        region = "ap-southeast-1";
        nodeId = 5;
      })
      (mkCoreNode "c" 2 {
        org = "CF";
        region = "ap-southeast-1";
        nodeId = 6;
      })
      (mkCoreNode "d" 1 {
        org = "IOHK";
        region = "us-east-2";
        nodeId = 7;
      })
    ];

  # Recovery nodes:
  withTestShelleyHardForkAtVersion3 = lib.recursiveUpdate {
    services.cardano-node.nodeConfig = {
      TestShelleyHardForkAtVersion = 3;
    };
  };

  recoveryCoreNodes =
    let mkCoreNode = r: idx: attrs:
      rec {
        name = "bft-dr-${r}-${toString idx}";
        region = regions.${r}.name;
        producers = filter (n: n != name) (map (c: c.name) recoveryCoreNodes);
      } // attrs;
    in
   map withTestShelleyHardForkAtVersion3 [
    # OBFT centralized nodes recovery nodes
    (mkCoreNode "a" 1 {
      org = "IOHK";
      nodeId = 1;
    })
    (mkCoreNode "a" 2 {
      org = "IOHK";
      nodeId = 2;
    })
    (mkCoreNode "f" 1 {
      org = "Emurgo";
      nodeId = 3;
    })
    (mkCoreNode "f" 2 {
      org = "Emurgo";
      nodeId = 4;
    })
    (mkCoreNode "c" 1 {
      org = "CF";
      nodeId = 5;
    })
    (mkCoreNode "c" 2 {
      org = "CF";
      nodeId = 6;
    })
    (mkCoreNode "b" 1 {
      org = "IOHK";
      nodeId = 7;
    })
  ];

in {

  coreNodes = coreNodes ++ recoveryCoreNodes;

  inherit relayNodes;

  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };
}
