{ name
, config
, ...
}:
with import ../nix {};
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  inherit (cardanoLib) mkProxyTopology;
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
    proxyPort = globals.cardanoNodePort;
    listen = "${legacyCardanoCfg.listenIp}:${toString globals.cardanoNodeLegacyPort}";
    address = "${legacyCardanoCfg.publicIp}:${toString globals.cardanoNodeLegacyPort}";
    topologyFile = legacyCardanoCfg.topologyYaml;
  };
  systemd.services.byron-proxy.serviceConfig.MemoryMax = "3.5G";


  networking.firewall.allowedTCPPorts = [ globals.cardanoNodePort ];

  services.cardano-node-legacy.nodeType = "relay";
}
