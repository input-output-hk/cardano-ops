{ pkgs, lib, options, config, name, nodes, resources,  ... }:
with (import ../nix {});
let
  inherit (import sourcePaths.iohk-nix {}) cardanoLib;

  nodePort = pkgs.globals.cardanoNodePort;
  monitoringPorts = [ 9100 9102 9113 ];
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
        mkRelayAddress (__trace nodeName node)
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

  services.cardano-node = {
    enable = true;
    inherit hostAddr;
    port = nodePort;
    inherit (globals) environment;
    environments = iohkNix.cardanoLib.environments;

    topology = builtins.toFile "topology.yaml" (builtins.toJSON
                 [ { nodeAddress = { addr = hostAddr; port = nodePort; };
                   inherit nodeId producers;
                 } ]);
  };
}
