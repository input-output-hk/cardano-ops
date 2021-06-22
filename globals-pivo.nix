pkgs: with pkgs.iohkNix.cardanoLib; rec {

  withMonitoring = false;
  domain = "pivo.dev.cardano.org";

  withExplorer = false;
  explorerForceSSL = false;
  ## To deploy the explorer on AWS use the following configuration.
  # withExplorer = true;
  # explorerForceSSL = true;
  # explorerHostName = "explorer.pivo.dev.cardano.org";

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
        TracingVerbosity= "MaximalVerbosity";
        defaultScribes = [
          [ "StdoutSK" "stdout" ]
          [ "FileSK"   "/var/lib/cardano-node/node.json" ]
        ];
        setupScribes = [
        { scKind = "StdoutSK"; scName = "stdout"; scFormat = "ScJson"; }
        { scKind = "FileSK"; scName = "/var/lib/cardano-node/node.json"; scFormat = "ScJson";
          scRotation = {
            rpLogLimitBytes = 300000000;
            rpMaxAgeHours   = 24;
            rpKeepFilesNum  = 20;
          }; }
        ];
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
