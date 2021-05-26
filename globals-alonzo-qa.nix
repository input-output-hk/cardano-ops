pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "alonzo-qa";

  withFaucet = true;
  withSmash = true;

  environmentConfigLocal = rec {
    relaysNew = "relays.${domain}";
    genesisFile = ./keys/genesis.json;
    nodeConfig =
      pkgs.lib.recursiveUpdate
      environments.alonzo-blue.nodeConfig
      {
        ShelleyGenesisFile = genesisFile;
        ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
        ByronGenesisFile = ./keys/byron/genesis.json;
        ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
        AlonzoGenesisFile = ./keys/genesis.alonzo.json;
        AlonzoGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/ALONZOGENHASH);
        TestShelleyHardForkAtEpoch = 1;
        TestAllegraHardForkAtEpoch = 2;
        TestMaryHardForkAtEpoch = 3;
        TestAlonzoHardForkAtEpoch = 10000;
      };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
