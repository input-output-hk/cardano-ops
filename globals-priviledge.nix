pkgs: with pkgs.iohkNix.cardanoLib; rec {

  withMonitoring = false;
  withExplorer = false;

  environmentName = "priviledge";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    genesisFile = ./keys/genesis.json;
    genesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
    nodeConfig = environments.shelley_qa.nodeConfig // {
      ShelleyGenesisFile = genesisFile;
      ShelleyGenesisHash = genesisHash;
      Protocol = "TPraos";
    };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
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
