pkgs: with pkgs; with lib; with topology-lib {
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
let

  bftNodes = [
    (mkBftCoreNode "a" 1 { org = "IOHK"; nodeId = 1; })
  ];

  nodes = with regions; map (composeAll [
    (withAutoRestartEvery 6)
    (withModule {
      services.cardano-node = {
        asserts = true;
        package = cardanoNodeServicePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes.cardano-node;
        useNewTopology = true;
        systemdSocketActivation = mkForce false;
      };
    })
  ]) (concatLists [
    (mkStakingPoolNodes "a" 1 "d" "P2P1" { org = "IOHK"; nodeId = 2; })
    (mkStakingPoolNodes "b" 2 "e" "P2P2" { org = "IOHK"; nodeId = 3; })
    (mkStakingPoolNodes "c" 3 "f" "P2P3" { org = "IOHK"; nodeId = 4; })
  ] ++ bftNodes);

  relayNodes = regionalConnectGroupWith bftNodes
    (filter (n: !(n ? stakePool)) nodes);

  coreNodes = filter (n: n ? stakePool) nodes;

in {

  inherit coreNodes relayNodes;

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
