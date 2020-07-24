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

  coreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [
        "c-a-2"
        "c-b-1" "c-c-1" "c-d-1"
        "e-a-1" "e-a-2"
        "e-b-1"
        "rel-a-1" "rel-a-2"
      ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [
        "c-a-1"
        "c-b-2" "c-c-2"
        "e-a-1" "e-a-2"
        "e-c-1" "e-d-1"
        "rel-a-1" "rel-a-2"
      ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [
        "c-b-2"
        "c-a-1" "c-c-1" "c-d-1"
        "e-b-1" "e-b-2"
        "e-a-1"
        "rel-f-1" "rel-f-2"
      ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [
        "c-b-1"
        "c-a-2" "c-c-2"
        "e-b-1" "e-b-2"
        "e-c-2" "e-d-2"
        "rel-f-1" "rel-f-2"
      ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [
        "c-c-2"
        "c-a-1" "c-b-1" "c-d-1"
        "e-c-1" "e-c-2"
        "e-a-1"
        "rel-c-1" "rel-c-2"
      ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [
        "c-c-1"
        "c-a-2" "c-b-2"
        "e-c-1" "e-c-2"
        "e-b-2" "e-d-2"
        "rel-c-1" "rel-c-2"
      ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "c-d-1";
      region = "us-east-2";
      producers = [
        "c-a-1" "c-b-1" "c-c-1"
        "e-d-1" "e-d-2"
        "e-a-1" "e-b-1" "e-c-1"
        "rel-b-1" "rel-b-2"
      ];
      org = "IOHK";
      nodeId = 7;
    }
   ];

   nextCoreNodes = [
    # OBFT centralized nodes
    {
      name = "bft-a-1";
      region = regions.a.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = regions.b.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = regions.c.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "bft-d-1";
      region = regions.b.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-d-1" "rel-d-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "bft-e-1";
      region = regions.c.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-e-1" "rel-e-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "bft-f-1";
      region = regions.f.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-f-1" "rel-f-2" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "bft-a-2";
      region = regions.a.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 7;
    }
    # stake pools
    {
      name = "stk-a-1";
      region = regions.a.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-a-1" "rel-a-2" ];
      org = "IOHK";
      nodeId = 8;
    }
    {
      name = "stk-b-1";
      region = regions.b.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-b-1" "rel-b-2" ];
      org = "IOHK";
      nodeId = 9;
    }
    {
      name = "stk-c-1";
      region = regions.c.name;
      producers = map (c: c.name) nextCoreNodes ++ [ "rel-c-1" "rel-c-2" ];
      org = "IOHK";
      nodeId = 10;
    }
  ];

  oldRelayNodes = [
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = ["c-a-2" "e-a-2" "e-b-1" "e-c-1" "e-d-1"];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = ["c-b-2" "e-b-2" "e-a-1" "e-d-1" "e-c-1"];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 10;
      producers = ["c-c-2" "e-c-2" "e-d-1" "e-a-1" "e-b-1"];
    }
    {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 11;
      producers = ["c-d-1" "e-d-2" "e-c-1" "e-a-1" "e-b-1"];
    }
    {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 12;
      producers = ["c-a-1" "e-a-1" "e-b-2" "e-c-2" "e-d-2"];
    }
    {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 13;
      producers = ["c-b-1" "e-b-1" "e-a-2" "e-c-2" "e-d-2"];
    }
    {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 14;
      producers = ["c-c-1" "e-c-1" "e-a-2" "e-b-2" "e-d-2"];
    }
    {
      name = "e-d-2";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 15;
      producers = ["c-d-1" "e-d-1" "e-a-2" "e-b-2" "e-c-2"];
    }
  ];

in {
  inherit coreNodes;

  relayNodes = map withAutoRestart (mkRelayTopology {
    inherit regions;
    coreNodes = coreNodes ++ nextCoreNodes;
  }) ++ nextCoreNodes ++ oldRelayNodes;

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 1000000000000;
      faucetFrontendUrl = "https://testnets.cardano.org/en/byron/tools/faucet/";
    };
  };

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
