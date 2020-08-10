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
      minRelays = 4;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 2;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 2;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 3;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 2;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 1;
    };
  };

  withTestShelleyHardForkAtVersion3 = lib.recursiveUpdate {
    services.cardano-node.nodeConfig = {
      TestShelleyHardForkAtVersion = 3;
    };
  };

  recoveryCoreNodes = map withTestShelleyHardForkAtVersion3 [
    # OBFT centralized nodes
    {
      name = "bft-dr-a-1";
      region = regions.a.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-dr-b-1";
      region = regions.b.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-dr-c-1";
      region = regions.c.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ [ "rel-dr-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-dr-d-1";
      region = regions.b.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-dr-e-1";
      region = regions.c.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-dr-f-1";
      region = regions.f.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-dr-a-2";
      region = regions.a.name;
      producers = map (c: c.name) recoveryCoreNodes;
      org = "IOHK";
      nodeId = 7;
    }
  ];

  bftCoreNodes = let
    mkBftCoreNode = r: idx: attrs:
      rec {
        name = "bft-${r}-${toString idx}";
        region = regions.${r}.name;
        producers =
          # some nearby relays:
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

  stakingPoolNodes = [];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions coreNodes;
  });

  oldCoreNodes = map (c:
    c // {
      producers = c.producers ++ [{
        addr = relayGroupForRegion c.region;
        port = globals.cardanoNodePort;
        valency = 3;
      }];
    }) [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [ "c-a-2" "c-a-3" "c-b-1" "c-c-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [ "c-a-1" "c-a-3" "c-b-2" "c-c-2" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-a-3";
      region = "eu-central-1";
      producers = [ "c-a-1" "c-a-2" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [ "c-b-2" "c-a-1" "c-c-1" ];
      org = "Emurgo";
      nodeId = 4;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [ "c-b-1" "c-a-2" "c-c-2" ];
      org = "Emurgo";
      nodeId = 5;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [ "c-c-2" "c-a-1" "c-b-1" ];
      org = "CF";
      nodeId = 6;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [ "c-c-1" "c-a-2" "c-b-2" ];
      org = "CF";
      nodeId = 7;
    }
  ];

in {

  coreNodes = coreNodes ++ recoveryCoreNodes;
  relayNodes = relayNodes;

  # Uncomment to access stopped old core nodes (for archeology purposes)
  #privateRelayNodes = oldCoreNodes;
}
