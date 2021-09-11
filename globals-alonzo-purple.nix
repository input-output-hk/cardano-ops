pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "alonzo-purple";

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
      environments.alonzo-qa.nodeConfig
      {
        ShelleyGenesisFile = ./keys/genesis.json;
        ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
        ByronGenesisFile = ./keys/byron/genesis.json;
        ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
        TestShelleyHardForkAtEpoch = 1;
        TestAllegraHardForkAtEpoch = 2;
        TestMaryHardForkAtEpoch = 3;
        TestAlonzoHardForkAtEpoch = 4;
        MaxKnownMajorProtocolVersion = 5;
        LastKnownBlockVersion-Major = 5;
      };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  # Every 5 hours
  relayUpdatePeriod = "0/5:00:00";

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };
}
