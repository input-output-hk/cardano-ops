{ name
, config
, ...
}:
with import ../nix {};
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  inherit (cardanoLib) mkProxyTopology;
  inherit (globals) cardanoNodePort cardanoNodeLegacyPort systemStart;
  legacyCardanoCfg = config.services.cardano-node-legacy;
in {

  imports = [
    ../modules/common-cardano-legacy.nix
    (sourcePaths.cardano-byron-proxy + "/nix/nixos")
  ];

  services.byron-proxy = {
    enable = true;
    inherit cardanoLib;
    environment = globals.environment;
    nodeId = name;
    proxyHost = legacyCardanoCfg.listenIp;
    proxyPort = cardanoNodePort;
    listen = "${legacyCardanoCfg.listenIp}:${toString cardanoNodeLegacyPort}";
    address = "${legacyCardanoCfg.publicIp}:${toString cardanoNodeLegacyPort}";
    topologyFile = legacyCardanoCfg.topologyYaml;
    extraOptions = "--system-start ${toString systemStart}";
  };

  networking.firewall.allowedTCPPorts = [ cardanoNodePort ];

  services.cardano-node-legacy.nodeType = "relay";
}
