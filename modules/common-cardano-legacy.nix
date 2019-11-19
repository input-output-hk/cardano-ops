{ pkgs, name, nodes, config, options, resources, ... }:
with (import ../nix {}); with lib;
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  inherit (iohkNix.cardanoLib) cardanoConfig;
  cfg = config.services.cardano-node-legacy;
  port = globals.cardanoNodeLegacyPort;
  hostName = name: "${name}.cardano";
  cardanoNodes = filterAttrs
    (_: node: node.config.services.cardano-node-legacy.enable
           or node.config.services.byron-proxy.enable or false)
    nodes;
  cardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) cardanoNodes;

  topology = {
    nodes = mapAttrs (name: node: let nodeCfg = node.config.services.cardano-node-legacy; in {
      type = nodeCfg.nodeType;
      region = node.config.deployment.ec2.region;
      host = hostName name;
      port = port;
    } // optionalAttrs (concatLists nodeCfg.staticRoutes != []) {
      static-routes = nodeCfg.staticRoutes;
    } // optionalAttrs (concatLists nodeCfg.dynamicSubscribe != []) {
      dynamic-subscribe = map (map (h: {
        "host" = if (nodes ? ${h}) then hostName h else h;
      })) nodeCfg.dynamicSubscribe;
    }) cardanoNodes;
  };

  nodeName = node: head (attrNames (filterAttrs (_: n: n == node) nodes));

  staticRouteIp = getStaticRouteIp resources nodes;
in {

  imports = [
    ./common.nix
  ];

  options = {
    services.cardano-node-legacy = {
      listenIp = mkOption { type = types.str; default = getListenIp nodes.${name};};
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      nodeType = mkOption { type = types.enum [ "core" "relay" "edge" ];};
      topologyYaml = mkOption {
        type = types.path;
        default = writeText "topology.yaml"  (builtins.toJSON topology);
      };

      staticRoutes = mkOption {
        default = [];
        type = types.listOf (types.listOf types.str);
        description = ''Static routes to peers.'';
      };

      dynamicSubscribe = mkOption {
        default = [];
        type = types.listOf (types.listOf types.str);
        description = ''Dnymic subscribe routes.'';
      };

    };
  };

  config = {
    environment.systemPackages = [ pkgs.telnet ];

    networking.firewall = {
      allowedTCPPorts = [ port ];

      # TODO: securing this depends on CSLA-27
      # NOTE: this implicitly blocks DHCPCD, which uses port 68
      allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
    };

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
      ${cfg.publicIp} ${hostName name}
      ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };


}
