pkgs: with pkgs; with lib; with topology-lib {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 3;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 2;
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
let

  bftCoreNodes = regionalConnectGroupWith (reverseList stakingPoolNodes) (fullyConnectNodes [
    # OBFT centralized nodes recovery nodes
    (mkBftCoreNode "a" 1 {
      org = "IOHK";
      nodeId = 1;
    })
    (mkBftCoreNode "b" 1 {
      org = "IOHK";
      nodeId = 2;
    })
    (mkBftCoreNode "c" 1 {
      org = "Emurgo";
      nodeId = 3;
    })
    (mkBftCoreNode "d" 1 {
      org = "Emurgo";
      nodeId = 4;
    })
    (mkBftCoreNode "e" 1 {
      org = "CF";
      nodeId = 5;
    })
    (mkBftCoreNode "f" 1 {
      org = "CF";
      nodeId = 6;
    })
    (mkBftCoreNode "a" 2 {
      org = "IOHK";
      nodeId = 7;
    })
  ]);

  stakingPoolNodes = regionalConnectGroupWith bftCoreNodes
  (fullyConnectNodes [
    (mkStakingPool "a" 1 "IOGS1" { nodeId = 8; })
    (mkStakingPool "b" 1 "IOGS2" { nodeId = 9; })
    (mkStakingPool "c" 1 "IOGS3" { nodeId = 10; })
    (mkStakingPool "d" 1 "IOGS4" { nodeId = 11; })
    (mkStakingPool "e" 1 "IOGS5" { nodeId = 12; })
    (mkStakingPool "f" 1 "IOGS6" { nodeId = 13; })
    (mkStakingPool "a" 2 "IOGS7" { nodeId = 14; })
  ]);

  coreNodes =  map (composeAll [
    (withAutoRestartEvery 6)
    #(withProfiling "time" ["bft-c-1" "bft-a-1"])
  ]) (bftCoreNodes ++ stakingPoolNodes);

  relayNodes = map (withAutoRestartEvery 6) (mkRelayTopology {
    inherit regions coreNodes;
    autoscaling = false;
  });

in {

  inherit coreNodes relayNodes;

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
}
