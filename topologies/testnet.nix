pkgs: with pkgs; with lib; with topology-lib;
let

  withAutoRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 *
        60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 2;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 2;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 2;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 2;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 2;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 2;
    };
  };

  forkingBftCoreNodes = [
    # OBFT centralized nodes
    {
      name = "bft-a-1";
      region = regions.a.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = regions.b.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = regions.c.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-d-1";
      region = regions.b.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-d-1" "rel-d-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-e-1";
      region = regions.c.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-e-1" "rel-e-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-f-1";
      region = regions.f.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-f-1" "rel-f-2" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-a-2";
      region = regions.a.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  stakingPoolNodes = [
    {
      name = "stk-a-1";
      region = regions.a.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 8;
    }
    {
      name = "stk-b-1";
      region = regions.b.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 9;
    }
    {
      name = "stk-c-1";
      region = regions.c.name;
      producers = map (c: c.name) forkingCoreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 10;
    }
  ];

  forkingCoreNodes = forkingBftCoreNodes ++ stakingPoolNodes;

  forkingRelayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions;
    coreNodes = forkingCoreNodes;
  });

  # Recovery nodes:
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
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-dr-b-1";
      region = recoveryRegions.b.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-dr-c-1";
      region = recoveryRegions.c.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-dr-d-1";
      region = recoveryRegions.b.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-d-1" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-dr-e-1";
      region = recoveryRegions.c.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-e-1" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-dr-f-1";
      region = recoveryRegions.f.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
        ++ [ "rel-dr-f-1" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-dr-a-2";
      region = recoveryRegions.a.name;
      producers = map (c: c.name) recoveryCoreNodes
        ++ map (c: c.name) forkingBftCoreNodes
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

in {
  coreNodes = forkingBftCoreNodes;
  relayNodes = forkingRelayNodes;
  privateRelayNodes = stakingPoolNodes ++ recoveryCoreNodes ++ recoveryRelayNodes;

  # Recovery plan: comment above three lines, uncomment following 3 lines and redeploy:
  #coreNodes = recoveryCoreNodes;
  #relayNodes = recoveryRelayNodes;
  #privateRelayNodes = forkingBftCoreNodes ++ forkingRelayNodes ++ stakingPoolNodes;

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 1000000000000;
      useByronWallet = false;
      faucetFrontendUrl = "https://testnets.cardano.org/en/cardano/tools/faucet/";
    };
  };
}
