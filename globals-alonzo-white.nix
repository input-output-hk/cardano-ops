pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "alonzo-white";

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
      environments.alonzo-blue.nodeConfig
      {
        ShelleyGenesisFile = ./keys/genesis.json;
        ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
        ByronGenesisFile = ./keys/byron/genesis.json;
        ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
        AlonzoGenesisFile = ./keys/genesis.alonzo.json;
        AlonzoGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/ALONZOGENHASH);
        TestShelleyHardForkAtEpoch = 1;
        TestAllegraHardForkAtEpoch = 2;
        TestMaryHardForkAtEpoch = 3;
        MaxKnownMajorProtocolVersion = 4;
      };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  # Every 5 hours:
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
