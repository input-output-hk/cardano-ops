pkgs: with pkgs; with lib; with topology-lib ;
let

  # Update for early release testing
  cardanoNodeNextPkgs = getCardanoNodePackages sourcePaths.cardano-node-next;

  cardanoNodeAdoptionMetricsPkgs = import (sourcePaths.cardano-node-adopt-metrics + "/nix")
    { gitrev = sourcePaths.cardano-node-adopt-metrics.rev; };

  regions = {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 35;
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

  bftCoreNodes = regionalConnectGroupWith (reverseList stakingPoolNodes)
  (fullyConnectNodes (map (withModule {
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
  ]));

  stakingPoolNodes = twoHopsConnectNodes [
    (mkStakingPool "a" 1 "IOG1" { nodeId = 8; })

    (mkStakingPool "b" 1 "IOGP2" { nodeId = 28; })
    (mkStakingPool "c" 1 "IOGP3" { nodeId = 29; })
    (mkStakingPool "d" 1 "IOGP4" { nodeId = 30; })
    (mkStakingPool "e" 1 "IOGP5" { nodeId = 31; })
    (mkStakingPool "f" 1 "IOGP6" { nodeId = 32; })
    (mkStakingPool "a" 2 "IOGP7" { nodeId = 33; })
    (mkStakingPool "b" 2 "IOGP8" { nodeId = 34; })
    (mkStakingPool "c" 2 "IOGP9" { nodeId = 35; })
    (mkStakingPool "d" 2 "IOGP10" { nodeId = 36; })
    (mkStakingPool "e" 2 "IOGP11" { nodeId = 37; })
    (mkStakingPool "f" 2 "IOGP12" { nodeId = 38; })
    (mkStakingPool "a" 3 "IOGP13" { nodeId = 39; })
    (mkStakingPool "b" 3 "IOGP14" { nodeId = 40; })
    (mkStakingPool "c" 3 "IOGP15" { nodeId = 41; })
    (mkStakingPool "d" 3 "IOGP16" { nodeId = 42; })
    (mkStakingPool "e" 3 "IOGP17" { nodeId = 43; })
    (mkStakingPool "f" 3 "IOGP18" { nodeId = 44; })
    (mkStakingPool "a" 4 "IOGP19" { nodeId = 45; })
    (mkStakingPool "b" 4 "IOGP20" { nodeId = 46; })
    (mkStakingPool "c" 4 "IOGP21" { nodeId = 47; })
    (mkStakingPool "d" 4 "IOGP22" { nodeId = 48; })
    (mkStakingPool "e" 4 "IOGP23" { nodeId = 49; })
    (mkStakingPool "f" 4 "IOGP24" { nodeId = 50; })
    (mkStakingPool "a" 5 "IOGP25" { nodeId = 51; })
    (mkStakingPool "b" 5 "IOGP26" { nodeId = 52; })
    (mkStakingPool "c" 5 "IOGP27" { nodeId = 53; })
    (mkStakingPool "d" 5 "IOGP28" { nodeId = 54; })
    (mkStakingPool "e" 5 "IOGP29" { nodeId = 55; })
    (mkStakingPool "f" 5 "IOGP30" { nodeId = 56; })
    (mkStakingPool "a" 6 "IOGP31" { nodeId = 57; })
    (mkStakingPool "b" 6 "IOGP32" { nodeId = 58; })
    (mkStakingPool "c" 6 "IOGP33" { nodeId = 59; })
    (mkStakingPool "d" 6 "LEO1"   { nodeId = 60; })
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
        cardanoNodePkgs = cardanoNodeAdoptionMetricsPkgs;
      };
    } [ "rel-a-3" "rel-b-3" "rel-c-3" "rel-d-3" "rel-e-3" "rel-f-3" ])
    # Uncomment for early release testing
    (forNodes {
      services.cardano-node = {
        cardanoNodePkgs = cardanoNodeNextPkgs;
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
    # Initial test node
    #{
    #  name = "memTestNode";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 501;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1290Pkgs;
    #    instances = mkForce 1;
    #    # profiling = "space-cost";
    #  };
    #}
    # Parallel test node for 1.30.0 testing
    #{
    #  name = "memTestNode30";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 502;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1300Pkgs;
    #    instances = mkForce 1;
    #    profiling = "space-heap";
    #  };
    #}
    # Parallel test node for 1.30.0-min testing
    #{
    #  name = "memTestNode30min";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 503;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1300Min2Pkgs;
    #    instances = mkForce 1;
    #    profiling = "space-heap";
    #  };
    #}
    # Parallel test node for 1.29.0 testing
    #{
    #  name = "memTestNode29";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 504;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1290Pkgs;
    #    instances = mkForce 1;
    #    profiling = "space-heap";
    #  };
    #}
    # Parallel test node for 1.30.0 testing with space profiling
    #{
    #  name = "memTestNode30ProfHT";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 506;
    #  # Default niv pin is at 1.30.0, so no cardanoNodePkgs change required
    #  services.cardano-node = {
    #    instances = mkForce 1;
    #    profiling = "space-cost";
    #  };
    #}
    # Parallel test node for 1.30.0-min testing with space profiling
    #{
    #  name = "memTestNode30minProfHT";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 507;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1300Min2Pkgs;
    #    instances = mkForce 1;
    #    profiling = "space-cost";
    #  };
    #}
    # Parallel test node for 1.29.0 testing with space profiling
    #{
    #  name = "memTestNode29ProfHT";
    #  region = regions.a.name;
    #  producers = [
    #    "memTestRelay"
    #  ];
    #  org = "IOHK";
    #  nodeId = 508;
    #  services.cardano-node = {
    #    cardanoNodePkgs = mkForce cardanoNodeTestNodes1290Pkgs;
    #    instances = mkForce 1;
    #    profiling = "space-cost";
    #  };
    #}
  ]);

  explorer-b.services.cardano-db-sync.restoreSnapshot = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-6943858-x86_64.tgz";
  explorer-a.services.cardano-db-sync.restoreSnapshot = "https://update-cardano-mainnet.iohk.io/cardano-db-sync/12/db-sync-snapshot-schema-12-block-6943858-x86_64.tgz";

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
