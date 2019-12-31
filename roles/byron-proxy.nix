{ name
, config
, nodes
, resources
, ...
}:
with import ../nix {};
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  legacyCardanoCfg = config.services.cardano-node-legacy;
  nodePort = globals.cardanoNodePort;
  hostName = name: "${name}.cardano";
  staticRouteIp = getStaticRouteIp resources nodes;
  cardanoNodes = lib.filterAttrs
    (_: node: node.config.node.roles.isCardanoCore)
    nodes;
  coreCardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) coreCardanoNodes;
  producersOpts = toString (map
    (c: "--producer-addr [${c.name}]:${toString nodePort}")
    coreCardanoHostList);
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
    extraOptions = producersOpts;
  };
  systemd.services.byron-proxy.serviceConfig.MemoryMax = "3.5G";


  networking.firewall.allowedTCPPorts = [ globals.cardanoNodePort ];

  services.cardano-node-legacy.nodeType = "relay";

  networking.extraHosts = ''
      ${lib.concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") coreCardanoHostList)}
  '';
}
