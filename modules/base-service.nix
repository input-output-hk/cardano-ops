{ pkgs, lib, options, config, name, nodes, resources,  ... }:
with (import ../nix {}); with lib;
let
  iohkNix = import sourcePaths.iohk-nix {};

  nodeId = config.node.nodeId;
  cfg = config.services.cardano-node;
  nodePort = globals.cardanoNodePort;
  hostAddr = getListenIp nodes.${name};

  monitoringPort = globals.cardanoNodePrometheusExporterPort;

  hostName = name: "${name}.cardano";
  staticRouteIp = getStaticRouteIp resources nodes;

  cardanoNodes = filterAttrs
    (_: node: node.config.services.cardano-node.enable
           or node.config.services.byron-proxy.enable or false)
    nodes;

  cardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) cardanoNodes;

  producers = map (n: {
    addr = if (nodes ? ${n}) then hostName n else n;
    port = nodePort;
    valency = 1;
  }) cfg.producers;

  topology =  builtins.toFile "topology.yaml" (builtins.toJSON {
    Producers = producers;
  });
in
{
  imports = [
    ./common.nix
    (sourcePaths.cardano-node + "/nix/nixos")
  ];

  options = {
    services.cardano-node = {
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      producers = mkOption {
        default = [];
        type = types.listOf types.str;
        description = ''Static routes to peers.'';
      };
    };
  };

  config = {

    services.monitoring-exporters.extraPrometheusExportersPorts = [ monitoringPort ];

    networking.firewall = {
      allowedTCPPorts = [ nodePort monitoringPort ];

      # TODO: securing this depends on CSLA-27
      # NOTE: this implicitly blocks DHCPCD, which uses port 68
      allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
    };

    services.cardano-node = {
      enable = true;
      extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
      environment = globals.environmentName;
      inherit hostAddr nodeId topology;
      port = nodePort;
      environments = {
        "${globals.environmentName}" = globals.environmentConfig;
      };
      nodeConfig = globals.environmentConfig.nodeConfig // {
        hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
        # TODO: re-enable JournalSK when output is human readable:
        #defaultScribes = [
        #  [
        #    "JournalSK"
        #    "cardano"
        #  ]
        #];
      };
    };
    systemd.services.cardano-node.serviceConfig.MemoryMax = "3.5G";
    # TODO remove next two line for next release cardano-node 1.7 release:
    systemd.services.cardano-node.scriptArgs = toString cfg.nodeId;
    systemd.services.cardano-node.preStart = ''
      if [ -d ${cfg.databasePath}-${toString cfg.nodeId} ]; then
        mv ${cfg.databasePath}-${toString cfg.nodeId} ${cfg.databasePath}
      fi
    '';

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
