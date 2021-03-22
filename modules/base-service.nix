pkgs: { options, config, name, nodes, resources,  ... }:
with pkgs; with lib;
let
  nodeId = config.node.nodeId;
  cfg = config.services.cardano-node;
  nodePort = globals.cardanoNodePort;
  hostAddr = getListenIp nodes.${name};

  monitoringPort = globals.cardanoNodePrometheusExporterPort;

  hostName = name: "${name}.cardano";
  staticRouteIp = getStaticRouteIp resources nodes;

  splitProducers = partition (n: nodes ? ${n.addr or n}) cfg.allProducers;
  deployedProducers = splitProducers.right;
  thirdParyProducers = splitProducers.wrong;
  splitDeployed = partition (n: nodes.${n}.config.node.roles.isCardanoCore) deployedProducers;
  coreNodeProducers = splitDeployed.right;
  relayNodeProducers = splitDeployed.wrong;
  splitRelays = partition (r: nodes.${r}.config.deployment.ec2.region == nodes.${name}.config.deployment.ec2.region) relayNodeProducers;
  sameRegionRelays = splitRelays.right;
  otherRegionRelays = splitRelays.wrong;

  cardanoHostList = map (nodeName: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) deployedProducers;

  toNormalizedProducer = n: {
    addr = let a = n.addr or n; in if (nodes ? ${a}) then hostName a else a;
    port = n.port or nodePort;
    valency = n.valency or 1;
  };

  producerShare = i: producers: let
      indexed = imap0 (idx: node: { inherit idx node;}) producers;
      filtered = filter ({idx, ...}: mod idx cfg.instances == i) indexed;
    in catAttrs "node" filtered;

  intraInstancesTopologies = topology-lib.connectNodesWithin
    cfg.maxIntraInstancesPeers
    (genList (i: {name = i;}) cfg.instances);

  instanceProducers = i: map toNormalizedProducer (concatLists [
      (concatMap (i: map (p: {
        addr = cfg.ipv6HostAddr;
        port = cfg.port + p;
      }) i.producers) (filter (x: x.name == i) intraInstancesTopologies))
      (producerShare i sameRegionRelays)
      (producerShare (cfg.instances - i - 1) otherRegionRelays)
      (producerShare i coreNodeProducers)
      (producerShare (cfg.instances - i - 1) thirdParyProducers)
    ]);

  cardano-node-service-def = (sourcePaths.cardano-node-service
    or sourcePaths.cardano-node) + "/nix/nixos";
in
{
  imports = [
    cardano-ops.modules.common
    cardano-ops.modules.custom-metrics
    cardano-node-service-def
  ];

  options = {
    services.cardano-node = {
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      allProducers = mkOption {
        default = [];
        type = types.listOf (types.either types.str types.attrs);
        description = ''Static routes to peers.'';
      };
      extraNodeConfig = mkOption {
        type = types.attrs;
        default = {};
      };
      totalMaxHeapSizeMbytes = mkOption {
        type = types.float;
        default = config.node.memory * 1024 * 0.875;
      };
      maxIntraInstancesPeers = mkOption {
        type = types.int;
        default = 5;
      };
    };
  };

  config = {

    environment.systemPackages = [ pkgs.cardano-cli ];
    environment.variables = {
      CARDANO_NODE_SOCKET_PATH = cfg.socketPath;
    } // globals.environmentVariables;
    services.monitoring-exporters.extraPrometheusExporters = genList (i: {
      job_name = "cardano-node";
      scrape_interval = "10s";
      port = monitoringPort + i;
      metrics_path = "/metrics";
      labels = optionalAttrs (i > 0) { alias = "${name}.${toString i}"; };
    }) cfg.instances;
    services.custom-metrics = {
      enable = true;
      statsdExporter = "node";
    };

    networking.firewall = {
      allowedTCPPorts = [ nodePort ];

      # TODO: securing this depends on CSLA-27
      # NOTE: this implicitly blocks DHCPCD, which uses port 68
      allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
    };

    services.cardano-node = {
      enable = true;
      systemdSocketActivation = true;
      # https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/runtime_control.html
      rtsArgs = [ "-N2" "-A16m" "-qg" "-qb" "-M${toString (cfg.totalMaxHeapSizeMbytes / cfg.instances)}M" ];
      environment = globals.environmentName;
      inherit cardanoNodePkgs hostAddr nodeId instanceProducers;
      ipv6HostAddr = mkIf (cfg.instances > 1) "::1";
      producers = mkDefault [];
      port = nodePort;
      environments = {
        "${globals.environmentName}" = globals.environmentConfig;
      };
      nodeConfig = recursiveUpdate globals.environmentConfig.nodeConfig (recursiveUpdate {
        hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
        # Use Journald output:
        setupScribes = [{
          scKind = "JournalSK";
          scName = "cardano";
          scFormat = "ScText";
        }];
        defaultScribes = [
          [
            "JournalSK"
            "cardano"
          ]
        ];
        # TraceMempool makes cpu usage x3, disabling by default:
        TraceMempool = false;
      } cfg.extraNodeConfig);
      extraServiceConfig = _: {
        serviceConfig = {
          MemoryMax = "${toString (1.15 * cfg.totalMaxHeapSizeMbytes / cfg.instances)}M";
          LimitNOFILE = "65535";
        };
      };
    };
    systemd.services.cardano-node = {
      path = [ gnutar gzip ];
      preStart = ''
        cd $STATE_DIRECTORY
        if [ -f db-restore.tar.gz ]; then
          rm -rf db-${globals.environmentName}*
          tar xzf db-restore.tar.gz
          rm db-restore.tar.gz
        fi
      '';
    };

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
