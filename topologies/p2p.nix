pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
    };
    b = { name = "us-east-2";      # US East (Ohio)
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
    };
    d = { name = "eu-west-2";      # Europe (London)
    };
    e = { name = "us-west-1";      # US West (N. California)
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
    };
  };

  bftNodes = [
    (mkBftCoreNode "a" 1 { org = "IOHK"; nodeId = 1; })
  ];

  nodes = with regions; map (composeAll [
    (withAutoRestartEvery 6)
    (withModule {
      services.cardano-node = {
        asserts = true;
        useNewTopology = true;
        systemdSocketActivation = mkForce false;
      };
    })
  ]) (concatLists [
    (mkStakingPoolNodes "a" 1 "d" "P2P1" { org = "IOHK"; nodeId = 2; })
    (mkStakingPoolNodes "b" 2 "e" "P2P2" { org = "IOHK"; nodeId = 3; })
    (mkStakingPoolNodes "c" 3 "f" "P2P3" { org = "IOHK"; nodeId = 4; })
    (mkStakingPoolNodes "d" 4 "a" "P2P4" { org = "IOHK"; nodeId = 5; })
    (mkStakingPoolNodes "e" 5 "b" "P2P5" { org = "IOHK"; nodeId = 6; })
    (mkStakingPoolNodes "f" 6 "c" "P2P6" { org = "IOHK"; nodeId = 7; })
    (mkStakingPoolNodes "a" 7 "d" "P2P7" { org = "IOHK"; nodeId = 8; })
    (mkStakingPoolNodes "b" 8 "e" "P2P8" { org = "IOHK"; nodeId = 9; })
    (mkStakingPoolNodes "c" 9 "f" "P2P9" { org = "IOHK"; nodeId = 10; })
    (mkStakingPoolNodes "d" 10 "a" "P2P10" { org = "IOHK"; nodeId = 11; })
    (mkStakingPoolNodes "e" 11 "b" "P2P11" { org = "IOHK"; nodeId = 12; })
    (mkStakingPoolNodes "f" 12 "c" "P2P12" { org = "IOHK"; nodeId = 13; })
    (mkStakingPoolNodes "a" 13 "d" "P2P13" { org = "IOHK"; nodeId = 14; })
    (mkStakingPoolNodes "b" 14 "e" "P2P14" { org = "IOHK"; nodeId = 15; })
    (mkStakingPoolNodes "c" 15 "f" "P2P15" { org = "IOHK"; nodeId = 16; })
    (mkStakingPoolNodes "d" 16 "a" "P2P16" { org = "IOHK"; nodeId = 17; })
    (mkStakingPoolNodes "e" 17 "b" "P2P17" { org = "IOHK"; nodeId = 18; })
    (mkStakingPoolNodes "f" 18 "c" "P2P18" { org = "IOHK"; nodeId = 19; })
    (mkStakingPoolNodes "a" 19 "d" "P2P19" { org = "IOHK"; nodeId = 20; })
    (mkStakingPoolNodes "b" 20 "e" "P2P20" { org = "IOHK"; nodeId = 21; })
  ] ++ bftNodes);

  relayNodes = regionalConnectGroupWith bftNodes
    (filter (n: !(n ? stakePool)) nodes);

  coreNodes = filter (n: n ? stakePool) nodes;

in {

  inherit coreNodes relayNodes regions;

  explorer = {
    services.cardano-node = {
      package = mkForce cardano-node;
    };
  };

  smash = {
    services.cardano-node = {
      package = mkForce cardano-node;
    };
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
    services.cardano-node = {
      package = mkForce cardano-node;
    };
  };

  monitoring = {
    services.monitoring-services.publicGrafana = false;
    services.nginx.virtualHosts."monitoring.${globals.domain}".locations."/p" = {
      root = ../static/pool-metadata;
    };
  };

}
