{ name
, config
, nodes
, resources
, ...
}:
with import ../nix {};
let
  cfg = config.services.byron-proxy;
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  legacyCardanoCfg = config.services.cardano-node-legacy;
  hostAddr = getListenIp nodes.${name};
  nodePort = globals.cardanoNodePort;
  hostName = name: "${name}.cardano";
  staticRouteIp = getStaticRouteIp resources nodes;
  cardanoNodes = lib.filterAttrs
    (_: node: node.config.services.cardano-node.enable
           or node.config.services.byron-proxy.enable or false)
    nodes;
  cardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) cardanoNodes;
  producersOpts = toString (map
    (p: "--producer-addr [${hostName p}]:${toString nodePort}")
    cfg.producers);
in {

  imports = [
    ../modules/common-cardano-legacy.nix
    (sourcePaths.cardano-byron-proxy + "/nix/nixos")
  ];

  options = {
    services.byron-proxy = {
      producers = lib.mkOption {
        default = [];
        type = lib.types.listOf lib.types.str;
        description = ''Static routes to peers.'';
      };
    };
  };

  config = {

    services.byron-proxy = {
      enable = true;
      cardanoLib = {
        inherit (cardanoLib) cardanoConfig;
        environments = {
          "${globals.environmentName}" = globals.environmentConfig;
        };
      };
      environment = globals.environmentName;
      nodeId = name;
      proxyHost = legacyCardanoCfg.listenIp;
      proxyPort = globals.cardanoNodePort;
      listen = "${legacyCardanoCfg.listenIp}:${toString globals.cardanoNodeLegacyPort}";
      address = "${legacyCardanoCfg.publicIp}:${toString globals.cardanoNodeLegacyPort}";
      topologyFile = legacyCardanoCfg.topologyYaml;
      extraOptions = producersOpts;
      logger.configFile = __toFile "log-config.json" (__toJSON (cardanoLib.defaultProxyLogConfig // {
        hasPrometheus = [ hostAddr 12799 ];
      }));
    };
    systemd.services.byron-proxy.serviceConfig.MemoryMax = "3.5G";


    networking.firewall.allowedTCPPorts = [ globals.cardanoNodePort ];

    services.cardano-node-legacy.nodeType = "relay";

    networking.extraHosts = ''
        ${lib.concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';

  };
}
