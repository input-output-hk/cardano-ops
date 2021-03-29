pkgs: with pkgs.iohkNix.cardanoLib; rec {

  withMonitoring = false;
  withExplorer = false;

  # This should match the name of the topology file.
  environmentName = "pivo";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    genesisFile = ./keys/genesis.json;
    genesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
    nodeConfig =
      pkgs.lib.recursiveUpdate
      environments.shelley_qa.nodeConfig
      {
        ShelleyGenesisFile = genesisFile;
        ShelleyGenesisHash = genesisHash;
        Protocol = "Pivo";
        TraceForge = true;
        TraceTxInbound = true;
      };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  environmentVariables = {
    F = "0.1";
    K = "10";
    SLOT_LENGTH = "0.2";
    EPOCH_LENGTH= "1000";
  };

  topology = import (./topologies + "/${environmentName}.nix") pkgs;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
