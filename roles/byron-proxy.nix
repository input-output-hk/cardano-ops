{ name
, nodes
, config
, ...
}:
with import ../nix {};
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  legacyCardanoCfg = config.services.cardano-node-legacy;
  hostAddr = getListenIp nodes.${name};
in {

  imports = [
    ../modules/common-cardano-legacy.nix
    (sourcePaths.cardano-byron-proxy + "/nix/nixos")
  ];

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
    logger.configFile = __toFile "log-config.json" (__toJSON (cardanoLib.defaultProxyLogConfig // {
      hasPrometheus = [ hostAddr 12799 ];
    }));
  };
  systemd.services.byron-proxy.serviceConfig.MemoryMax = "3.5G";


  networking.firewall.allowedTCPPorts = [ globals.cardanoNodePort ];

  services.cardano-node-legacy.nodeType = "relay";
}
