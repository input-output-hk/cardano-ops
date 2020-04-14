pkgs: rec {

  withMonitoring = false;
  withLegacyExplorer = false;
  explorerAliases = [];

  environmentName = "shelley-dev";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    edgeNodes = [
      "18.197.234.239"
      "3.125.14.209"
      "52.58.137.138"
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
