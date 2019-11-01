{ pkgs, lib, options, config, nodes, resources,  ... }:
with (import ../nix {});
let
  inherit (import sources.iohk-nix {}) cardanoLib;

  toCardanoEnvName = env: {
    # mapping of environnement name from globals.nix to the one defined in cardanoLib:
    stagingshelleyshort = "shelley_staging_short";
    stagingshelley      = "shelley_staging";
  }.${env} or env;

  nodePort = 3001;
  hostAddr = if options.networking.privateIPv4.isDefined then config.networking.privateIPv4 else "0.0.0.0";
  nodeId = config.services.cardano-node.nodeId;
  mkProducer = node: { addr = node.config.networking.privateIPv4; port = 3001; valency = 1; };
in
{
  imports = [
    iohk-ops-lib.modules.common
    (sources.cardano-node + "/nix/nixos")
  ];

  networking.firewall = {
    allowedTCPPorts = [ nodePort ];

    # TODO: securing this depends on CSLA-27
    # NOTE: this implicitly blocks DHCPCD, which uses port 68
    allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
  };

  services.cardano-node = {
    enable = true;
    pbftThreshold = "0.9";
    inherit (cardanoLib.environments.${toCardanoEnvName globals.environment})
      genesisFile
      genesisHash;
    consensusProtocol = "real-pbft";
    inherit hostAddr;
    port = nodePort;
    topology = builtins.toFile "topology.yaml" (builtins.toJSON
                 [ { nodeAddress = { addr = hostAddr; port = nodePort; };
                   inherit nodeId;
                   producers = map mkProducer (builtins.attrValues nodes);
                 } ]);
    logger.configFile = ./iohk-monitoring-config.yaml;
  };
}
