pkgs: with pkgs; with lib; with topology-lib {
    a = { name = "eu-central-1";   /* Europe (Frankfurt)       */ };
    b = { name = "us-east-2";      /* US East (Ohio)           */ };
    c = { name = "ap-southeast-1"; /* Asia Pacific (Singapore) */ };
    d = { name = "eu-west-2";      /* Europe (London)          */ };
  };
let

  stakingPoolNodes = fullyConnectNodes [
    (mkStakingPool "a" 1 "IOHK1" { nodeId = 1; })
    (mkStakingPool "b" 1 "IOHK2" { nodeId = 2; })
    (mkStakingPool "c" 1 "IOHK3" { nodeId = 3; })
  ];

  coreNodes = map (withAutoRestartEvery 6) stakingPoolNodes;

  relayNodes = map (composeAll [
    (withAutoRestartEvery 6)
    #(withProfiling "time" ["rel-a-1"])
  ]) (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
    maxProducersPerNode = 20;
    maxInRegionPeers = 5;
  });

in {

  inherit coreNodes relayNodes;

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


  explorer = {
    services.nginx.virtualHosts.${globals.explorerHostName}.locations."/p" = lib.mkIf (__pathExists ../static/pool-metadata) {
      root = ../static/pool-metadata;
    };
    services.cardano-graphql = {
      allowListPath = mkForce null;
      allowIntrospection = true;
    };
  };
}
