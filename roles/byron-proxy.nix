{ name
, config
, ...
}:
with import ../nix {};
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  legacyCardanoCfg = config.services.cardano-node-legacy;
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
  };

  networking.firewall.allowedTCPPorts = [ globals.cardanoNodePort ];

  services.cardano-node-legacy.nodeType = "relay";
}
