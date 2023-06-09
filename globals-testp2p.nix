pkgs: with pkgs.iohkNix.cardanoLib; rec {

  # deploymentName = "testp2p";
  environmentName = "testp2p";

  # relaysNew = globals.environmentConfig.relaysNew;

  withNixopsExperimental = true;
  withMonitoring = true;
  withExplorer = false;
  withFaucet = false;
  withMetadata = false;
  withSmash = false;
  withSnapshots = false;
  withSubmitApi = false;
  minCpuPerInstance = 1;
  minMemoryPerInstance = 4;

  nbInstancesPerRelay = 2;

  environmentConfig = let
    readHash = file: builtins.replaceStrings ["\n"] [""] (builtins.readFile file);
  in rec {
    relays = "relays.${pkgs.globals.domain}";
    relaysNew = "relays.${pkgs.globals.domain}";
    nodeConfig =
      pkgs.lib.recursiveUpdate
      environments.private.nodeConfig
      {
        EnableP2P = false;
        ExperimentalProtocolsEnabled = false;
        ByronGenesisFile = ./keys/byron-genesis.json;
        ByronGenesisHash = readHash ./keys/byron-genesis.hash;
        ShelleyGenesisFile = ./keys/shelley-genesis.json;
        ShelleyGenesisHash = readHash ./keys/shelley-genesis.hash;
        AlonzoGenesisFile = ./keys/alonzo-genesis.json;
        AlonzoGenesisHash = readHash ./keys/alonzo-genesis.hash;
        ConwayGenesisFile = ./keys/conway-genesis.json;
        ConwayGenesisHash = readHash ./keys/conway-genesis.hash;
        TraceForge = true;
        TraceTxInbound = true;
      };
      explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  topology = import (./topologies + "/${environmentName}.nix") pkgs;
}
