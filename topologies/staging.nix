pkgs: with pkgs; with lib; with topology-lib;
let

  withAutoRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 *
        60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

  withTestShelleyHardForkAtVersion3 = lib.recursiveUpdate {
    services.cardano-node.nodeConfig = {
      TestShelleyHardForkAtVersion = 3;
    };
  };

  recoveryRegions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 1;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 1;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 1;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 1;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 1;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 1;
    };
  };

  recoveryCoreNodes = map withTestShelleyHardForkAtVersion3 [
    # OBFT centralized nodes
    {
      name = "bft-dr-a-1";
      region = recoveryRegions.a.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-dr-b-1";
      region = recoveryRegions.b.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-dr-c-1";
      region = recoveryRegions.c.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-dr-d-1";
      region = recoveryRegions.b.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-d-1" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-dr-e-1";
      region = recoveryRegions.c.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-e-1" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-dr-f-1";
      region = recoveryRegions.f.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-f-1" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-dr-a-2";
      region = recoveryRegions.a.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingCoreNodes
        ++ [ "rel-dr-a-1" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  recoveryRelayNodes = map withTestShelleyHardForkAtVersion3 (mkRelayTopology {
    relayPrefix = "rel-dr";
    regions = recoveryRegions;
    coreNodes = recoveryCoreNodes;
  });

  forkingCoreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [ "c-a-2" "c-a-3" "c-b-1" "c-c-1" "e-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [ "c-a-1" "c-a-3" "c-b-2" "c-c-2" "e-a-2" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-a-3";
      region = "eu-central-1";
      producers = [ "c-a-1" "c-a-2" "e-b-3" "e-c-3" "e-a-3" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [ "c-b-2" "c-a-1" "c-c-1" "e-b-1" ];
      org = "Emurgo";
      nodeId = 4;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [ "c-b-1" "c-a-2" "c-c-2" "e-b-1" ];
      org = "Emurgo";
      nodeId = 5;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [ "c-c-2" "c-a-1" "c-b-1" "e-c-1" ];
      org = "CF";
      nodeId = 6;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [ "c-c-1" "c-a-2" "c-b-2" "e-c-1" ];
      org = "CF";
      nodeId = 7;
    }
  ];

  forkingRelayNodes = [
    # Group 1 (original group)
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = ["c-a-1" "e-a-2" "e-a-3" "e-b-1" "e-c-1"];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = ["c-b-1" "e-b-2" "e-b-3" "e-a-1" "e-c-1"];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 10;
      producers = ["c-c-1" "e-c-2" "e-c-3" "e-a-1" "e-b-1"];
    }

    # Likely will want to update the producers of all these nodes once created
    # Group 2

    {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 21;
      producers = ["c-a-2" "e-a-1" "e-a-3" "e-b-2" "e-c-2"];
    }
    {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 22;
      producers = ["c-b-2" "e-b-1" "e-b-3" "e-a-2" "e-c-2"];
    }
    {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 23;
      producers = ["c-c-2" "e-c-1" "e-c-3" "e-a-2" "e-b-2"];
    }

    {
      name = "e-a-3";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 24;
      producers = ["c-a-3" "e-a-1" "e-a-2" "e-b-3" "e-c-3"];
    }
    {
      name = "e-b-3";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 25;
      producers = ["e-b-1" "e-b-2" "e-a-3" "e-c-3"];
    }
    {
      name = "e-c-3";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 26;
      producers = ["e-c-2" "e-a-3" "e-b-3"];
    }

    {
      name = "e-a-4";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 27;
      producers = ["e-a-2" "e-a-3" "e-b-4" "e-c-4"];
    }
    {
      name = "e-b-4";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 28;
      producers = ["e-b-2" "e-b-3" "e-a-4" "e-c-4"];
    }
    {
      name = "e-c-4";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 29;
      producers = ["e-c-2" "e-c-3" "e-a-4" "e-b-4"];
    }
  ];

in {

  coreNodes = forkingCoreNodes;
  relayNodes = forkingRelayNodes;
  privateRelayNodes = recoveryCoreNodes ++ recoveryRelayNodes;

  # Recovery plan: comment above three lines, uncomment following 3 lines and redeploy:
  #coreNodes = recoveryCoreNodes;
  #relayNodes = recoveryRelayNodes;
  #privateRelayNodes = forkingCoreNodes ++ forkingRelayNodes;


  legacyCoreNodes = [];
  legacyRelayNodes = [];
  byronProxies = [];
}
