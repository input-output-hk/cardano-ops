pkgs: with pkgs; with lib; with topology-lib;
let
  withDailyRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 * 60 * 60 + 60 * (5 * (def.nodeId or 0));
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
    # backup OBFT centralized nodes
    {
      name = "bft-a-1";
      region = "eu-central-1";
      producers = [ "bft-b-1" "bft-c-1" "stk-a-1-IOHK1" "rel-a-1" "rel-d-1" "rel-a-2" "rel-d-2" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = "ap-northeast-1";
      producers = [ "bft-c-1" "bft-a-1" "stk-b-1-IOHK2" "rel-b-1" "rel-e-1" "rel-b-2" "rel-e-2"  ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = "ap-southeast-1";
      producers = [ "bft-a-1" "bft-b-1" "stk-c-1-IOHK3" "rel-c-1" "rel-f-1" "rel-c-2" "rel-f-2" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "stk-a-1-IOHK1";
      region = "eu-central-1";
      producers = [ "stk-b-1-IOHK2" "stk-c-1-IOHK3" "bft-a-1" "rel-a-2" "rel-e-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "stk-b-1-IOHK2";
      region = "ap-northeast-1";
      producers = [ "stk-c-1-IOHK3" "stk-a-1-IOHK1" "bft-b-1" "rel-b-2" "rel-f-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "stk-c-1-IOHK3";
      region = "ap-southeast-1";
      producers = [ "stk-a-1-IOHK1" "stk-b-1-IOHK2" "bft-c-1" "rel-c-2" "rel-d-2" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

  relayNodesBaseDef = mkRelayTopology {
    inherit regions coreNodes;
  };

in {
  inherit coreNodes;

  relayNodes = map withDailyRestart relayNodesBaseDef;

  monitoring = {
    services.monitoring-services.publicGrafana = true;
  };

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = false;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 1000000000;
      useByronWallet = false;
      #faucetFrontendUrl = "https://testnets.cardano.org/en/shelley/tools/faucet/";
    };
  };

  explorer = withDailyRestart {
    services.nginx.virtualHosts."${globals.explorerHostName}.${globals.domain}".locations."/p" = lib.mkIf (__pathExists ../static/pool-metadata) {
      root = ../static/pool-metadata;
    };
  };
}
