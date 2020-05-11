pkgs:
let
  benchmarkingParamsFile = ./benchmarking-cluster-params.json;
  benchmarkingParams =
    if __pathExists benchmarkingParamsFile
    then let r = __fromJSON (__readFile benchmarkingParamsFile);
         in if __hasAttr "meta" r
            then if __hasAttr "defaultProfile" r.meta then r
                 else abort "${benchmarkingParamsFile} must define 'meta.defaultProfile'"
            else abort "${benchmarkingParamsFile} must defined the 'meta' section"
    else abort "Benchmarking requires ${benchmarkingParamsFile} to exist.  Please, refer to documentation.";
  benchmarkingTopologyFile =
    ./topologies + "/bench-txgen-simple-${toString benchmarkingParams.meta.nodeCount}.nix";
  benchmarkingTopology =
    if __pathExists benchmarkingTopologyFile
    then __trace "Using topology:  ${benchmarkingTopologyFile}"
         (import benchmarkingTopologyFile)
    else abort "Benchmarking topology file implied by configured node count ${benchmarkingParams.meta.nodeCount} does not exist: ${benchmarkingTopologyFile}";

  ### Benchmarking profiles are, currently, essentially name-tagger
  ### generator configs.
  benchmarkingProfileNameEnv = __getEnv("BENCHMARKING_PROFILE");
  ## WARNING: this logic must correspond to select_benchmarking_profile
  ##          in bench.sh.
  benchmarkingProfileName = if benchmarkingProfileNameEnv == ""
                            then benchmarkingParams.meta.defaultProfile
                            else benchmarkingProfileNameEnv;
  benchmarkingProfile =
    if __hasAttr benchmarkingProfileName benchmarkingParams
    then __trace "Using profile:  ${benchmarkingProfileName}"
         benchmarkingParams."${benchmarkingProfileName}"
    else abort "${benchmarkingParamsFile} does not define benchmarking profile '${benchmarkingProfileName}'.";
  metadata = {
    inherit benchmarkingProfileName benchmarkingProfile benchmarkingTopology;
  };
  reportDeployment = x:
    __trace "DEPLOYMENT_METADATA=${__toFile "nixops-metadata.json" (__toJSON metadata)}" x;
in reportDeployment (rec {

  withMonitoring = false;
  withLegacyExplorer = false;
  withTxGenerator = true;

  environmentName = "bench-txgen-simple-${benchmarkingProfileName}";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    edgePort = pkgs.globals.cardanoNodePort;
    confKey = abort "legacy nodes not supported by benchmarking environment";
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
    generatorConfig = benchmarkingProfile;
  };

  topology = benchmarkingTopology;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
})
