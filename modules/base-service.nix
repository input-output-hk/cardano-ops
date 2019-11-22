{ pkgs, lib, options, config, name, nodes, resources,  ... }:
with (import ../nix {});
let
  iohkNix = import sourcePaths.iohk-nix {};

  nodePort = pkgs.globals.cardanoNodePort;

  # Ports 9100, 9102, 9113 are already handled in monitoring-exporters by default
  # Prometheus port 12798 is included here since it applies to multiple roles
  monitoringPorts = [ 12798 ];

  hostAddr = if options.networking.privateIPv4.isDefined then config.networking.privateIPv4 else "0.0.0.0";
  nodeId = config.services.cardano-node.nodeId;

  # TODO: this doesn't work, perhaps publicIPv4 is empty, I need a way to filter out self node

  mkRelayAddress = node: {
    addr = node.config.networking.publicIPv4;
    port = node.config.services.cardano-node.port;
    valency = 1;
  };

  mkProxyAddress = node: {
    addr = node.config.networking.publicIPv4;
    port = node.config.services.byron-proxy.proxyPort;
    valency = 1;
  };

  compact = builtins.filter (e: e != null);
  pp = v: __trace (__toJSON v) v;

  nodeAddress = nodeName: node:
    if (nodeName != name) then
      if (node.config.node.roles.isCardanoRelay or false) then
        mkRelayAddress node
      else if (node.config.node.roles.isByronProxy or false) then
        mkProxyAddress node
      else null
    else null;

  producers = compact (builtins.attrValues (builtins.mapAttrs nodeAddress nodes));
  region = config.deployment.ec2.region;
  loggerConfig = import ./iohk-monitoring-config.nix;
in
{
  imports = [
    ./common.nix
    (sourcePaths.cardano-node + "/nix/nixos")
  ];

  networking.firewall = {
    allowedTCPPorts = [ nodePort ] ++ monitoringPorts;

    # TODO: securing this depends on CSLA-27
    # NOTE: this implicitly blocks DHCPCD, which uses port 68
    allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
  };

  # TODO: remove rec when prometheus binding is a parameter
  services.cardano-node = rec {
  # services.cardano-node = {
    enable = true;
    inherit hostAddr;
    port = nodePort;
    inherit (globals) environment;
    environments = iohkNix.cardanoLib.environments;

    # TODO: remove prometheus port override when prometheus binding is a parameter
    nodeConfig = environments.${environment}.nodeConfig // { hasPrometheus = 12797; };

    topology = builtins.toFile "topology.yaml" (builtins.toJSON
                 [ { nodeAddress = { addr = hostAddr; port = nodePort; };
                   inherit nodeId producers;
                 } ]);
  };
}
