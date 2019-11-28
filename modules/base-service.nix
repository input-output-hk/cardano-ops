{ pkgs, lib, options, config, name, nodes, resources,  ... }:
with (import ../nix {}); with lib;
let
  iohkNix = import sourcePaths.iohk-nix {};

  nodeId = config.node.nodeId;
  cfg = config.services.cardano-node;
  nodePort = pkgs.globals.cardanoNodePort;
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

  topology =  builtins.toFile "topology.yaml" (builtins.toJSON (lib.mapAttrsToList (nodeName: node: {
        _file = ./base-service.nix;
        nodeId = node.config.node.nodeId;
        nodeAddress = {
          addr = if (nodeName == name)
            then hostAddr
            else hostName nodeName;
          port = nodePort;
        };
        producers = if (nodeName == name)
          then producers
          else [];
      }) cardanoNodes));

  loggerConfig = import ./iohk-monitoring-config.nix // {
    hasPrometheus = 12797; #FIXME: use monitoringPort and remove nginx proxy.
  };
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

    # TODO: remove rec when prometheus binding is a parameter
    services.cardano-node = {
      extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-RTS" ];
      enable = true;
      inherit hostAddr nodeId topology;
      port = nodePort;
      environment = globals.environmentName;
      environments = {
        "${globals.environmentName}" = globals.environmentConfig;
      };

      # TODO: remove prometheus port override when prometheus binding is a parameter
      nodeConfig = globals.environmentConfig.nodeConfig // loggerConfig // {
        NodeId = nodeId;
      };
    };
    systemd.services.cardano-node.serviceConfig.MemoryMax = "3.5G";

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
