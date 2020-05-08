pkgs: rec {

  withMonitoring = false;
  withLegacyExplorer = false;
  withTxGenerator = true;

  environmentName = "bench-txgen-simple";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    edgePort = pkgs.globals.cardanoNodePort;
    confKey = abort "legacy nodes not supported by shelley-dev environment";
    genesisFile = ./keys/genesis.json;
    genesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
    private = true;
    networkConfig = pkgs.iohkNix.cardanoLib.environments.shelley_staging_short.networkConfig // {
      GenesisFile = genesisFile;
      GenesisHash = genesisHash;
      NumCoreNodes = builtins.length topology.coreNodes;
    };
    nodeConfig = pkgs.iohkNix.cardanoLib.environments.shelley_staging_short.nodeConfig // {
      GenesisFile = genesisFile;
      GenesisHash = genesisHash;
      NumCoreNodes = builtins.length topology.coreNodes;
    };
    txSubmitConfig = {
      inherit (networkConfig) RequiresNetworkMagic;
      GenesisFile = genesisFile;
      GenesisHash = genesisHash;
    } // pkgs.iohkNix.cardanoLib.defaultExplorerLogConfig;

    ## This is overlaid atop the defaults in the tx-generator service,
    ## as specified in the 'cardano-benchmarking' repository.
    ##
    ## Note, that this only affects the Tx generation options:
    ##   txCount addTxSize inputsPerTx outputsPerTx txFee tps
    generatorConfig =
      if __pathExists ./generator-params.json
      then __trace "Generator:  using ${./generator-params.json}"
        (__fromJSON (__readFile ./generator-params.json))
      else {};
  };

  topology = import ./topologies/bench-txgen-simple.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
