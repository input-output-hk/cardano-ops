pkgs: with pkgs; with lib; with topology-lib ;
let
  # Update for early release testing
  cardanoNodeNextPackages = getCardanoNodePackages sourcePaths.cardano-node-next;

  cardanoNodeAdoptionMetricsPackages = import (sourcePaths.cardano-node-adopt-metrics + "/nix")
    { gitrev = sourcePaths.cardano-node-adopt-metrics.rev; };

  # For legacy and p2p topology relay configuration
  maxProducersPerNode = 20;

  # For generating lists of relays, by region, to use p2p format. For a given region and count
  # start with the last relay index in a region and working back to the first.
  # Do it from last to first as the first several relay index series tend to be more heavily used,
  # including for other customizations.
  p2pRelayRegionList = region: count: let
    regionMinRelays = regions.${region}.minRelays;
    p2pPercent = (count + 0.0) / regionMinRelays * 100;
    p2pTrace = exp: builtins.trace ''region "${region}" now has ${toString count} of ${toString regionMinRelays} relays using p2p, or ${toString p2pPercent}%'' exp;
  in if count <= regions.${region}.minRelays
    then
      p2pTrace (lib.genList (index: "rel-${region}-${toString (regionMinRelays - index)}") count)
    else
      abort ''p2pRelayRegionList generation must use count (${toString count}) less than the region "${region}" minRelays (${toString regionMinRelays}).'';

  regions = {
    # Scale down ~10% on 2024-01-12
    a = { name = "eu-central-1";   # Europe (Frankfurt);
      minRelays = 36;
    };
    b = { name = "us-east-2";      # US East (Ohio)
      minRelays = 23;
    };
    c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
      minRelays = 9;
    };
    d = { name = "eu-west-2";      # Europe (London)
      minRelays = 14;
    };
    e = { name = "us-west-1";      # US West (N. California)
      minRelays = 14;
    };
    f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
      minRelays = 9;
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
    # The following legacy defns of the stake pools will fail on a socket assertion now that mainnet is set EnableP2P by default.
    # However, since these machines have been migrated, we don't want to be able to deploy these machines, so the assertion prevents us from doing so.
    # Ideally, we would simply remove these machines from the topology, but the stack was written with the assumption that block producers must be defined.
    (mkStakingPool "a" 1 "IOG1" { nodeId = 8; })
    (mkStakingPool "b" 1 "IOGP2" { nodeId = 28; })
    (mkStakingPool "c" 1 "IOGP3" { nodeId = 29; })
    (mkStakingPool "d" 1 "IOGP4" { nodeId = 30; })

    # If we did need to re-deploy the pools, the following service modification is one way we could do so
    # (mkStakingPool "a" 1 "IOG1" { nodeId = 8; services.cardano-node = {useNewTopology = lib.mkForce false; extraNodeConfig = {EnableP2P = lib.mkForce false;};};})
    # (mkStakingPool "b" 1 "IOGP2" { nodeId = 28; services.cardano-node = {useNewTopology = lib.mkForce false; extraNodeConfig = {EnableP2P = lib.mkForce false;};};})
    # (mkStakingPool "c" 1 "IOGP3" { nodeId = 29; services.cardano-node = {useNewTopology = lib.mkForce false; extraNodeConfig = {EnableP2P = lib.mkForce false;};};})
    # (mkStakingPool "d" 1 "IOGP4" { nodeId = 30; services.cardano-node = {useNewTopology = lib.mkForce false; extraNodeConfig = {EnableP2P = lib.mkForce false;};};})
  ];

  coreNodes = bftCoreNodes ++ stakingPoolNodes;

  relayNodes = map (composeAll [
    (forNodes {
      # Leave one legacy network topology canary
      services.cardano-node = {
        useNewTopology = false;
        extraNodeInstanceConfig = i: {
          EnableP2P = false;
        };
      };
    } [ "rel-a-1" ])
    (forNodes {
      services.cardano-node = {
        extraNodeInstanceConfig = i: optionalAttrs (i == 0) {
          TraceMempool = true;
        };
      };
      services.tcpdump = {
        enable = true;
        bucketName = "mainnet-pcap";
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
        extraNodeInstanceConfig = i: optionalAttrs (i == 0) {
          TraceBlockFetchClient = true;
          TraceMempool = true;
        };
      };
    } [ "rel-a-3" "rel-b-3" "rel-c-3" "rel-d-3" "rel-e-3" "rel-f-3" ])
    # (forNodes {
    #   services.cardano-node.cardanoNodePackages = cardanoNodeNextPackages;
    # } [ "rel-a-4" "rel-b-4" "rel-c-4" "rel-d-4" "rel-e-4" "rel-f-4" ])
    (forNodes {
      boot.kernel.sysctl."net.ipv4.tcp_slow_start_after_idle" = 0;
    } [ "rel-a-5" "rel-b-5" "rel-c-5" "rel-d-5" "rel-e-5" "rel-f-5" ])
    (forNodes {
      services.cardano-node.totalMaxHeapSizeMbytes = 11300.0 * 2;
      systemd.services.cardano-node-0.serviceConfig.MemoryMax = lib.mkForce "13000M";
    } [ "rel-a-30" ])

    # All node instances on each relay listed below will utilize p2p.
    (forNodes {
      services.cardano-node = {
        # Options to enable p2p relays in mixed topology cluster:

        # To ensure non-systemd socket activated instances bind the same port on the machine, ie: 3001,
        # This ensures they all receive incoming traffic.
        # Since systemd sockets are not used, there is no so_reuseport socket UID conflict.
        # For non-mingw32 hosts, node enables so_reuseport for socket configuration by default.
        shareIpv4port = true;

        # Turn systemd socket activation off due to an so_reuseport UID kernel conflict when binding sockets for re-use as non-root user.
        systemdSocketActivation = lib.mkForce false;

        # Use p2p
        useNewTopology = true;

        # Transform any p2p multi-member accessPoints groups into single member accessPoints.
        useSingleMemberAccessPoints = true;

        # Make 3rd party producers localRoots rather than publicRoots for a 1:1 equivalency with legacy topology.
        useInstancePublicProducersAsProducers = true;

        # Don't use any chain source outside of declared localRoots until after slot correlating with ~2024-01-10 21:45:09Z:
        usePeersFromLedgerAfterSlot = 128908821;

        extraNodeConfig = {
          PeerSharing = false;
          TargetNumberOfRootPeers = 100;
          TargetNumberOfKnownPeers = 100;


          # Ensure p2p relay node instances utilize the same number of producers as legacy relays as best as possible
          TargetNumberOfActivePeers = maxProducersPerNode;
        };
      };
    } (lib.flatten [
      # See the nixops deploy [--build-only] [--include ...] trace for calculated p2p percentages per region.
      # Leave one legacy topology relay as a canary, rel-a-1
      (p2pRelayRegionList "a" 35) # Currently 36 total region a relays -- 1 remains as non-p2p canary
      (p2pRelayRegionList "b" 23) # Currently 23 total region b relays
      (p2pRelayRegionList "c" 9) # Currently 9 total region c relays
      (p2pRelayRegionList "d" 14) # Currently 14 total region d relays
      (p2pRelayRegionList "e" 14) # Currently 14 total region e relays
      (p2pRelayRegionList "f" 9) # Currently 9 total region f relays
    ]))
  ]) (
    map (withModule {
      # Legacy topology uses systemd socket activation with shared ipv6 address but
      # differing ipv6 ports for intra-machine peer producers on multi-instance relays.
      services.cardano-node.shareIpv6port = false;
    }
  ) (mkRelayTopology {
    inherit maxProducersPerNode regions;
    coreNodes = stakingPoolNodes;
    autoscaling = false;
    scaledown = true;
    maxInRegionPeers = 5;
  }));

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

  monitoring = {
    services.monitoring-services = {
      publicGrafana = false;
      prometheus.basicAuthFile = writeText "prometheus.htpasswd" globals.static.prometheusHtpasswd;
    };
  };
}
