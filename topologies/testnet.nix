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

  bftCoreNodes = [
    # OBFT centralized nodes
    {
      name = "bft-a-1";
      region = regions.a.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = regions.b.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = regions.c.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-d-1";
      region = regions.b.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-d-1" "rel-d-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-e-1";
      region = regions.c.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-e-1" "rel-e-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-f-1";
      region = regions.f.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-f-1" "rel-f-2" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-a-2";
      region = regions.a.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  stakingPoolNodes = [
    {
      name = "stk-a-1";
      region = regions.a.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 8;
    }
    {
      name = "stk-b-1";
      region = regions.b.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 9;
    }
    {
      name = "stk-c-1";
      region = regions.c.name;
      producers = map (c: c.name) coreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 10;
    }
  ];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
    maxProducersPerNode = 21;
  });

in {
  coreNodes = bftCoreNodes;
  inherit relayNodes;
  privateRelayNodes = stakingPoolNodes;

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
