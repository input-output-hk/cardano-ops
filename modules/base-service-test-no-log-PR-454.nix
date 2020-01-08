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

  # Modify this definition so relays pulling from different
  # environments don't interact with each other
  cardanoNodes = filterAttrs
    (_: node: _ == name) nodes;

  #cardanoNodes = filterAttrs
  #  (_: node: node.config.services.cardano-node.enable
  #         or node.config.services.byron-proxy.enable or false)
  #  nodes;

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
in
{
  imports = [
    ./common.nix
    (sourcePaths.cardano-node-PR-454 + "/nix/nixos")
  ];

  options = {
    services.cardano-node = {
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      producers = mkOption {
        default = [];
        type = types.listOf types.str;
        description = ''Static routes to peers.'';
      };
      environmentName = mkOption {
        default = "staging";
        type = types.str;
        description = ''Environment from iohkNix to use (default: staging)'';
      };
      haskellArgs = mkOption {
        default = [ "+RTS" "-h" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
        type = types.listOf types.str;
        description = ''Haskell arguments to pass to cardano-node service'';
      };
      logging = mkOption {
        default = true;
        type = types.bool;
        description = ''Whether to enable Haskell logging'';
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

    systemd.coredump.enable = true;
    services.cardano-node = {
      enable = true;
      extraArgs = cfg.haskellArgs;

      # This will be customized on a per relay basis
      #environment = globals.environmentName;
      environment = cfg.environmentName;

      inherit hostAddr nodeId topology;
      port = nodePort;
      #environments = {
      #  "${globals.environmentName}" = globals.environmentConfig;
      #};

      # Allow using our customized environmentName
      #nodeConfig = globals.environmentConfig.nodeConfig // {
      nodeConfig = globals.environments.${cfg.environmentName}.nodeConfig // {
        hasPrometheus = [ hostAddr 12798 ];
        NodeId = nodeId;
      } // lib.optionalAttrs (cfg.logging == false) {
        TurnOnLogging = false;
      };
    };
    systemd.services.cardano-node.serviceConfig.MemoryMax = "3.5G";
    systemd.services.cardano-node.serviceConfig.LimitCORE = "infinity";
    systemd.services.cardano-node.serviceConfig.Restart = mkForce "no";

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
