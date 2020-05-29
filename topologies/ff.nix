pkgs: with pkgs;
let
  withDailyRestart = def: lib.recursiveUpdate {
    systemd.services.cardano-node.serviceConfig.RuntimeMaxSec = 24 * 60 * 60;
  } def;
  relayNodesBaseDef = [
    # relays
    ({
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = [ "c-a-1" "e-b-1" "e-c-1" "e-d-1" "e-a-2" ];
      deployment.ec2.instanceType = lib.mkForce "t3.xlarge";
      boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
    } // (builtins.removeAttrs cardano-ops.roles.relay-high-load ["imports"]))

    (withDailyRestart {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = [ "c-b-1" "e-c-1" "e-a-1" "e-d-1" "e-b-2" ];
    })
    (withDailyRestart {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 10;
      producers = [ "c-c-1" "e-a-1" "e-b-1" "e-d-1" "e-c-2" ];
    })
    (withDailyRestart {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 11;
      producers = [ "c-a-1" "c-b-1" "c-c-1" "e-a-1" "e-b-1" "e-c-1" "e-d-2" ];
    })

    (withDailyRestart {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 12;
      producers = [ "c-a-2" "e-b-2" "e-c-2" "e-d-2" "e-a-1" ];
      services.cardano-node.profiling = "time";
    })
    (withDailyRestart {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 13;
      producers = [ "c-b-2" "e-c-2" "e-a-2" "e-d-2" "e-b-1" ];
    })
    (withDailyRestart {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 14;
      producers = [ "c-c-2" "e-a-2" "e-b-2" "e-d-2" "e-c-1" ];
    })
    (withDailyRestart {
      name = "e-d-2";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 15;
      producers = [ "c-a-2" "c-b-2" "c-c-2" "e-a-2" "e-b-2" "e-c-2" "e-d-1" ];
    })
  ];

  ffProducers = lib.imap0 (index: cp: cp // { inherit index; }) globals.static.ffProducers;

  nbRelay = lib.length relayNodesBaseDef;

  relayNodes = lib.imap0 (i: r: r // {
    producers = r.producers ++ (lib.filter (p: lib.mod p.index nbRelay == i) ffProducers);
  }) relayNodesBaseDef;

in {
  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];

  monitoring = {
    services.monitoring-services.publicGrafana = true;
  };

  "${globals.faucetHostname}" = {
    services.cardano-faucet = {
      anonymousAccess = true;
      faucetLogLevel = "DEBUG";
      secondsBetweenRequests = 86400;
      lovelacesToGiveAnonymous = 1000000000;
      lovelacesToGiveApiKeyAuth = 1000000000000;
    };
  };

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [ "c-b-1" "c-c-1" "c-a-2" "e-a-1" "e-d-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [ "c-c-1" "c-a-1" "c-b-2" "e-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [ "c-a-1" "c-b-1" "c-c-2" "e-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [ "c-b-2" "c-c-2" "c-a-1" "e-a-2" "e-d-2" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [ "c-c-2" "c-a-2" "c-b-1" "e-b-2" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [ "c-a-2" "c-b-2" "c-c-1" "e-c-2" ];
      org = "IOHK";
      nodeId = 6;
    }
  ];

  inherit relayNodes;
}
