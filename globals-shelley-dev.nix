pkgs: rec {

  withMonitoring = false;

  environmentName = "shelley-dev";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    edgeNodes = [
      "18.196.133.111"
      "13.239.95.144"
      "35.173.24.158"
    ];
    edgePort = pkgs.globals.cardanoNodePort;
    confKey = abort "legacy nodes not supported by shelley-dev environment";
    genesisFile = ./keys/genesis.json;
    genesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
    private = true;
    networkConfig = pkgs.iohkNix.cardanoLib.environments.shelley_staging_short.networkConfig // {
      GenesisHash = genesisHash;
      NumCoreNodes = builtins.length topology.coreNodes;
    };
    nodeConfig = pkgs.iohkNix.cardanoLib.environments.shelley_staging_short.nodeConfig // {
      GenesisHash = genesisHash;
      NumCoreNodes = builtins.length topology.coreNodes;
    };
  };

  topology = import ./topologies/shelley-dev.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
