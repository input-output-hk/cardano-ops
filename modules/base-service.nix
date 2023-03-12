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

  toNormalizedProducerGroup = producers: {
    accessPoints= map (n: {
      address= let a = n.addr or n; in if (nodes ? ${a}) then hostName a else a;
      port = n.port or nodePort;
      valency = n.valency or 1;
    }) producers;
    valency = length producers;
  };

  producerShare = i: producers: let
      indexed = imap0 (idx: node: { inherit idx node;}) producers;
      filtered = filter ({idx, ...}: mod idx cfg.instances == i) indexed;
    in catAttrs "node" filtered;

  intraInstancesTopologies = topology-lib.connectNodesWithin
    cfg.maxIntraInstancesPeers
    (genList (i: {name = i;}) cfg.instances);

  instanceProducers = i: map toNormalizedProducerGroup (filter (g: length g != 0) [
      (concatMap (i: map (p: {
        addr = cfg.ipv6HostAddr;
        port = cfg.port + p;
      }) i.producers) (filter (x: x.name == i) intraInstancesTopologies))
      (producerShare i sameRegionRelays)
      (producerShare (cfg.instances - i - 1) otherRegionRelays)
      (producerShare i coreNodeProducers)
    ]);

  instancePublicProducers = i: map toNormalizedProducerGroup (filter (g: length g != 0) [
    (producerShare (cfg.instances - i - 1) thirdParyProducers)
  ]);

in
{
  imports = [
    cardano-ops.modules.common
    cardano-ops.modules.custom-metrics
    cardano-node-services-def
    (import (cardano-node-services-def + "/cardano-tracer-service.nix")
      ## XXX: ugly -- svclib should really move to iohk-nix.
      (pkgs
       //
       { commonLib = import ((sourcePaths.cardano-node-service or sourcePaths.cardano-node) + "/nix/svclib.nix") { inherit pkgs; }; }))
  ];

  options = {
    services.cardano-node = {
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      allProducers = mkOption {
        default = [];
        type = types.listOf (types.either types.str types.attrs);
        description = ''Static routes to peers.'';
      };
      totalMaxHeapSizeMbytes = mkOption {
        type = types.float;
        default = config.node.memory * 1024 * 0.790;
      };
      totalCpuCores = mkOption {
        type = types.int;
        default = min config.node.cpus (2 * cfg.instances);
      };
      maxIntraInstancesPeers = mkOption {
        type = types.int;
        default = 5;
      };
    };
  };

  config = {

    environment.systemPackages = with cfg.cardanoNodePackages; [ cardano-cli ];
    environment.variables = globals.environmentVariables // {
      CARDANO_NODE_SOCKET_PATH = cfg.socketPath 0;
    };
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
      rtsArgs = [ "-N${toString (cfg.totalCpuCores / cfg.instances)}" "-A16m" "-qg" "-qb" "-M${toString (cfg.totalMaxHeapSizeMbytes / cfg.instances)}M" ];
      environment = globals.environmentName;
      cardanoNodePackages = lib.mkDefault cardanoNodePackages;
      inherit hostAddr nodeId instanceProducers instancePublicProducers;
      ipv6HostAddr = mkIf (cfg.instances > 1) "::1";
      producers = mkDefault [];
      publicProducers = mkDefault [];
      port = nodePort;
      environments = {
        "${globals.environmentName}" = globals.environmentConfig;
      };
      nodeConfig = finaliseNodeConfig
                     globals.benchmarkingProfile.node.withNewTracing
                     globals.environmentConfig.nodeConfig;
      extraNodeConfig =
        finaliseNodeConfig
          globals.benchmarkingProfile.node.withNewTracing
      {
        hasPrometheus = [ cfg.hostAddr globals.cardanoNodePrometheusExporterPort ];
        # The maximum number of used peers when fetching newly forged blocks:
        MaxConcurrencyDeadline = 4;
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
      };
      extraServiceConfig = _: {
        serviceConfig = {
          # Allow time to uncompress when restoring db
          TimeoutStartSec = "1h";
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
      serviceConfig = {
        # Allow time to uncompress when restoring db
        TimeoutStartSec = "1h";
      };
    };

    services.cardano-tracer = {
      enable = true;
      acceptingSocket = (cfg.stateDir 0) + "/tracer.socket";
      logRoot = cfg.stateDir 0;
      rotation.rpLogLimitBytes = 1000 * 1000 * 1000;
    };
    systemd.services.cardano-tracer.serviceConfig.Environment = [("HOME=" + cfg.stateDir 0)];

    users.users.cardano-node.isSystemUser = true;

    services.dnsmasq.enable = true;

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
