pkgs: with pkgs; with lib; with topology-lib ;
let

  # Update for early release testing
  cardanoNodeNextPkgs = getCardanoNodePackages sourcePaths.cardano-node-next;

  cardanoNodeAdoptionMetricsPkgs = import (sourcePaths.cardano-node-adopt-metrics + "/nix")
    { gitrev = sourcePaths.cardano-node-adopt-metrics.rev; };

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 40;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 25;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 10;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 15;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 15;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 10;
    };
  };

  bftCoreNodes = map (withModule {
    # Disable monitoring of bft nodes (do not produces blocks anymore)
    services.monitoring-exporters.metrics = false;
  }) [
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
  ];

  stakingPoolNodes = fullyConnectNodes [
    (mkStakingPool "a" 1 "IOG1" { nodeId = 8; })

    (mkStakingPool "b" 1 "IOGP2" { nodeId = 28; })
    (mkStakingPool "c" 1 "IOGP3" { nodeId = 29; })
    (mkStakingPool "d" 1 "IOGP4" { nodeId = 30; })
  ];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map (composeAll [
    (forNodes {
      services.cardano-node = {
        extraNodeInstanceConfig = i: optionalAttrs (i == 0) {
          TraceMempool = true;
        };
      };
    } [ "rel-a-1" "rel-b-1" "rel-c-1" "rel-d-1" "rel-e-1" "rel-f-1" ])
    (forNodes {
      services.cardano-node = {
        extraNodeInstanceConfig = i: optionalAttrs (i == 0) {
          TraceBlockFetchClient = true;
        };
      };
    } [ "rel-a-2" "rel-b-2" "rel-c-2" "rel-d-2" "rel-e-2" "rel-f-2" ])
    (forNodes {
      services.cardano-node = {
        cardanoNodePackages = cardanoNodeNextPkgs;
        extraNodeInstanceConfig = i: optionalAttrs (i == 0) {
          TraceBlockFetchClient = true;
          TraceMempool = true;
        };
      };
    } [ "rel-a-3" "rel-b-3" "rel-c-3" "rel-d-3" "rel-e-3" "rel-f-3" ])
    (forNodes {
      services.cardano-node = {
        cardanoNodePackages = cardanoNodeNextPkgs;
      };
    } [ "rel-a-4" "rel-b-4" "rel-c-4" "rel-d-4" "rel-e-4" "rel-f-4" ])
    (forNodes {
      boot.kernel.sysctl."net.ipv4.tcp_slow_start_after_idle" = 0;
    } [ "rel-a-5" "rel-b-5" "rel-c-5" "rel-d-5" "rel-e-5" "rel-f-5" ])
  ]) (mkRelayTopology {
      inherit regions;
      coreNodes = stakingPoolNodes;
      autoscaling = false;
      maxProducersPerNode = 20;
      maxInRegionPeers = 5;
    });

in {

  inherit coreNodes relayNodes regions;

  privateRelayNodes = [
    # Parallel test node for 1.30.1 testing with no profiling and -c RTS added
    {
      name = "memTestNode30NoProf";
      region = regions.a.name;
      producers = [
        "memTestRelay"
      ];
      org = "IOHK";
      nodeId = 505;
      services.cardano-node = {
        rtsArgs = [ "-c" ];
        instances = mkForce 1;
      };
      services.monitoring-exporters.metrics = false;
    }
  ] ++ (map (r: recursiveUpdate r {
    services.monitoring-exporters.metrics = false;
  }) [
    # Test node for when syncing is needed; should be nixops stopped during any tests on the test nodes
    {
      name = "memTestRelay";
      region = regions.a.name;
      producers = [
        (envRegionalRelaysProducer regions.a.name 1)
      ];
      org = "IOHK";
      nodeId = 500;
      services.cardano-node = {
        instances = mkForce 1;
      };
    }
  ]);

  explorer-a.services.cardano-db-sync.restoreSnapshot = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/13/db-sync-snapshot-schema-13-block-7685639-x86_64.tgz";
  explorer-b.services.cardano-db-sync.restoreSnapshot = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/13/db-sync-snapshot-schema-13-block-7685639-x86_64.tgz";
  explorer-c.services.cardano-db-sync.restoreSnapshot = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/13/db-sync-snapshot-schema-13-block-7685639-x86_64.tgz";

  monitoring = {
    services.monitoring-services = {
      publicGrafana = false;
      prometheus.basicAuthFile = writeText "prometheus.htpasswd" globals.static.prometheusHtpasswd;
    };
  };

  metadata = {
    node = {
      org = "CF";
      roles.isPublicSsh = true;
    };
  };

}
