pkgs: with pkgs; with lib; with topology-lib;
let

  withAutoRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig = {
      RuntimeMaxSec = 6 *
        60 * 60 + 60 * (5 * (def.nodeId or 0));
    };
  } def;

in {
  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };


  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = false;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequestsAnonymous = 86400;
      secondsBetweenRequestsApiKeyAuth = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 10000000000;
      useByronWallet = false;
    };
  };

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "bft-a-1";
      region = "eu-central-1";
      producers = [ "bft-b-1" "bft-c-1" "rel-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = "ap-northeast-1";
      producers = [ "bft-c-1" "bft-a-1" "rel-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = "ap-southeast-1";
      producers = [ "bft-a-1" "bft-b-1" "rel-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "stk-a-1-IOHK1";
      region = "eu-central-1";
      producers = [ "stk-b-1-IOHK2" "stk-c-1-IOHK3" "stk-d-1-IOHK4" "rel-a-1" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "stk-b-1-IOHK2";
      region = "ap-northeast-1";
      producers = [ "stk-c-1-IOHK3" "stk-d-1-IOHK4" "stk-a-1-IOHK1" "rel-b-1" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "stk-c-1-IOHK3";
      region = "ap-southeast-1";
      producers = [ "stk-d-1-IOHK4" "stk-a-1-IOHK1" "stk-b-1-IOHK2" "rel-c-1" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

  relayNodes = [
    # relays
    {
      name = "rel-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 101;
      producers = [ "bft-a-1" "stk-a-1-IOHK1" "rel-b-1" "rel-c-1" "rel-d-1" ] ++ thirdPartyRelays;
    }
    {
      name = "rel-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 102;
      producers = [ "bft-b-1" "stk-b-1-IOHK2" "rel-c-1" "rel-a-1" "rel-d-1" ] ++ thirdPartyRelays;
    }
    {
      name = "rel-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 103;
      producers = [ "bft-c-1" "stk-c-1-IOHK3" "rel-a-1" "rel-b-1" "rel-d-1" ] ++ thirdPartyRelays;
    }
    {
      name = "rel-d-1";
      region = "us-east-1";
      org = "IOHK";
      nodeId = 104;
      producers = [ "stk-d-1-IOHK4" "rel-a-1" "rel-b-1"  ] ++ thirdPartyRelays;
    }
  ];
  explorer = {
    services.nginx.virtualHosts."${globals.explorerHostName}.${globals.domain}".locations."/p" = lib.mkIf (__pathExists ../static/pool-metadata) {
      root = ../static/pool-metadata;
    };
  };
}
