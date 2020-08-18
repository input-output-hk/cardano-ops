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
  in connectNodesWithin 6 [
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
    autoscaling = false;
    maxProducersPerNode = 21;
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

  coreNodes = coreNodes;
  relayNodes = relayNodes;

  # Uncomment to access stopped old core nodes (for archeology purposes)
  #privateRelayNodes = oldCoreNodes;
}
