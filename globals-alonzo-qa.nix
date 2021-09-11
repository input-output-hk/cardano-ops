pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "alonzo-qa";

  withFaucet = true;
  withSmash = true;
  explorerBackends = {
    a = explorer11;
  };
  explorerBackendsInContainers = true;

  environmentConfigLocal = rec {
    relaysNew = "relays.${domain}";
    nodeConfig =
      pkgs.lib.recursiveUpdate
      environments.alonzo-white.nodeConfig
      {
        ShelleyGenesisFile = ./keys/genesis.json;
        ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
        ByronGenesisFile = ./keys/byron/genesis.json;
        ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
        TestShelleyHardForkAtEpoch = 0;
        TestAllegraHardForkAtEpoch = 0;
        TestMaryHardForkAtEpoch = 0;
        TestAlonzoHardForkAtEpoch = 0;
        MaxKnownMajorProtocolVersion = 5;
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
