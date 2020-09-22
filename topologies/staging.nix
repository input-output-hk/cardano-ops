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
    mkBftCoreNode = mkBftCoreNodeForRegions regions;
  in regionalConnectGroupWith (reverseList stakingPoolNodes) (fullyConnectNodes [
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

  stakingPoolNodes = [];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
  });

in {

  inherit coreNodes relayNodes;

}
