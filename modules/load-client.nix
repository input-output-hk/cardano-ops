pkgs: { config, options, nodes, name, ... }:
with pkgs; with lib;
let
  cfg = config.services.cardano-node;
  nodePort = globals.cardanoNodePort;
  hostAddr = getListenIp nodes.${name};
  monitoringPort = globals.cardanoNodePrometheusExporterPort;
in
{
  imports = [
    cardano-ops.modules.common
    (sourcePaths.cardano-node + "/nix/nixos")
  ];

  networking.firewall = {
    allowedTCPPorts = [ nodePort monitoringPort ];

    # TODO: securing this depends on CSLA-27
    # NOTE: this implicitly blocks DHCPCD, which uses port 68
    allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
  };

  services.cardano-node = {
    enable = true;
    inherit cardanoNodePkgs;
    rtsArgs = [ "-N2" "-A10m" "-qg" "-qb" "-M3G"];
    environment = globals.environmentName;
    port = nodePort;
    environments = {
      "${globals.environmentName}" = globals.environmentConfig;
    };
    nodeConfig = globals.environmentConfig.nodeConfig // {
      hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
      # Use Journald output:
      defaultScribes = [
        [
          "JournalSK"
          "cardano"
        ]
      ];
    };
    topology = iohkNix.cardanoLib.mkEdgeTopology {
      inherit (cfg) port;
      edgeHost = globals.relaysNew;
      edgeNodes = [];
    };
  };
}
