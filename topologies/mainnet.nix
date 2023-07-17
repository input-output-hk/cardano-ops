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
    (forNodes {
      services.cardano-node.cardanoNodePackages = cardanoNodeNextPackages;
    } [ "rel-a-4" "rel-b-4" "rel-c-4" "rel-d-4" "rel-e-4" "rel-f-4" ])
    (forNodes {
      boot.kernel.sysctl."net.ipv4.tcp_slow_start_after_idle" = 0;
    } [ "rel-a-5" "rel-b-5" "rel-c-5" "rel-d-5" "rel-e-5" "rel-f-5" ])

    # Begin transitioning relays to p2p.
    # All node instances on each relay listed below will utilize p2p.
    (forNodes {
      networking.localCommands = ''
        # Use a loopback interface for out of band intra-machine multi-node-instance comms.
        # The ipv6 assignment is similar to ipv4 loopback for recognizability and the traffic
        # for which will not be externally routed.
        for i in $(seq 1 ${toString pkgs.globals.nbInstancesPerRelay}); do
          ip -6 address add ::127.0.0.$i/96 dev lo || true
        done
      '';

      services.cardano-node = {
        # Options to enable p2p relays in mixed topology cluster:

        # To ensure non-systemd socket activated instances bind the same port on the machine, ie: 3001,
        # This ensures they all receive incoming traffic.
        # Since systemd sockets are not used, there is no so_reuseport socket UID conflict.
        # For non-mingw32 hosts, node enables so_reuseport for socket configuration by default.
        shareIpv4port = true;

        # The typical cardano-ops ipv4 legacy cluster topology uses systemd socket activation with an ipv6
        # localhost listener of ::1 with different port binding to enable intra-machine node peering.
        # Without systemd socket activation, node cli only parameterizes a single port option that is used for both ipv4 and ipv6.
        # Enabling this option will ensure topology port declaration for intra-machine peering uses the same port.
        # This means, though, that the ipv6 addresses for each instance on a machine will need to be different.
        shareIpv6port = lib.mkForce true;

        # Per above, we wish to increment the ipv6 address for each instance to create a unique intra-machine node listener.
        shareIpv6Address = false;

        # Turn systemd socket activation off due to an so_reuseport UID kernel conflict when binding sockets for re-use as non-root user.
        systemdSocketActivation = lib.mkForce false;

        # Use p2p
        useNewTopology = true;

        # Transform any p2p multi-member accessPoints groups into single member accessPoints.
        useSingleMemberAccessPoints = true;

        # Make 3rd party producers localRoots rather than publicRoots for a 1:1 equivalency with legacy topology.
        useInstancePublicProducersAsProducers = true;

        # Don't use any chain source outside of declared localRoots until after slot correlating with ~2023-07-04 21:44Z:
        usePeersFromLedgerAfterSlot = 96940733;

        # Ensure p2p relay node instances utilize the same number of producers as legacy relays as best as possible
        extraNodeConfig.TargetNumberOfActivePeers = maxProducersPerNode;
      };
    } (lib.flatten [
      # See the nixops deploy [--build-only] [--include ...] trace for calculated p2p percentages per region.
      (p2pRelayRegionList "a" 16) # Currently 40 total region a relays, each represents 2.5% of region total
      (p2pRelayRegionList "b" 10) # Currently 25 total region b relays, each represents 4.0% of region total
      (p2pRelayRegionList "c" 4) # Currently 10 total region c relays, each represents 10.0% of region total
      (p2pRelayRegionList "d" 6) # Currently 15 total region d relays, each represents 6.67% of region total
      (p2pRelayRegionList "e" 6) # Currently 15 total region e relays, each represents 6.67% of region total
      (p2pRelayRegionList "f" 4) # Currently 10 total region f relays, each represents 10.0% of region total
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

  metadata = {
    node = {
      org = "CF";
      roles.isPublicSsh = true;
    };
  };

}
