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
in
{
  imports = [
    (sources.cardano-node + "/nix/nixos")
  ];

  services.cardano-node = {
    enable = true;
    pbftThreshold = "0.9";
    inherit (cardanoLib.environments.${toCardanoEnvName globals.environment})
      genesisFile
      genesisHash;
    consensusProtocol = "real-pbft";
    hostAddr = if options.networking.privateIPv4.isDefined then config.networking.privateIPv4 else "0.0.0.0";
    port = nodePort;
    logger.configFile = ./iohk-monitoring-config.yaml;
  };
}
