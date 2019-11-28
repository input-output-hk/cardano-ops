self: super: {
  globals = (import ./globals-defaults.nix self) // rec {

    static = import ./static;

    withMonitoring = false;

    withExplorer = true;

    deploymentName = "${builtins.baseNameOf ./.}";

    domain = "${deploymentName}.dev.iohkdev.io";

    environmentName = "shelley-dev";

    environmentConfig = rec {
      relays = "relays.${domain}";
      edgeNodes = [
        "18.197.234.239"
        "3.125.14.209"
        "52.58.137.138"
      ];
      edgePort = self.globals.cardanoNodePort;
      confKey = abort "legacy nodes not supported by shelley-dev environment";
      genesisFile = ./keys/genesis.json;
      genesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
      private = true;
      networkConfig = self.iohkNix.cardanoLib.environments.shelley_staging_short.networkConfig // {
        GenesisHash = genesisHash;
        NumCoreNodes = builtins.length topology.coreNodes;
      };
      nodeConfig = self.iohkNix.cardanoLib.environments.shelley_staging_short.nodeConfig // {
        GenesisHash = genesisHash;
        NumCoreNodes = builtins.length topology.coreNodes;
      };
    };

    topology = import ./topologies/shelley-dev.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "dev-deployer";
          dns = "dev-deployer";
        };
      };
    };
  };
}
