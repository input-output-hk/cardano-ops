pkgs:
let
  benchmarkingParamsFile = ./benchmarking-cluster-params.json;
  benchmarkingParams =
    if __pathExists benchmarkingParamsFile
    then let r = __fromJSON (__readFile benchmarkingParamsFile);
         in if __hasAttr "meta" r
            then if __hasAttr "default_profile" r.meta then r
                 else abort "${benchmarkingParamsFile} must define 'meta.default_profile'"
            else abort "${benchmarkingParamsFile} must defined the 'meta' section"
    else abort "Benchmarking requires ${toString benchmarkingParamsFile} to exist.  Please, refer to documentation.";
  benchmarkingTopologyFile =
    ./topologies + "/bench-txgen-simple-${toString (__length benchmarkingParams.meta.node_names)}.nix";
  benchmarkingTopology =
    if __pathExists benchmarkingTopologyFile
    then __trace "Using topology:  ${benchmarkingTopologyFile}"
         (import benchmarkingTopologyFile)
    else abort "Benchmarking topology file implied by configured node count ${__length benchmarkingParams.meta.node_names} does not exist: ${benchmarkingTopologyFile}";

  ### Benchmarking profiles are, currently, essentially name-tagger
  ### generator configs.
  benchmarkingProfileNameEnv = __getEnv("BENCHMARKING_PROFILE");
  ## WARNING: this logic must correspond to select_benchmarking_profile
  ##          in bench.sh.
  benchmarkingProfileName = if benchmarkingProfileNameEnv == ""
                            then benchmarkingParams.meta.default_profile
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

  benchmarkingLogConfig = {
    defaultScribes = [
      [ "StdoutSK" "stdout" ]
      [ "FileSK"   "/var/lib/cardano-node/logs/node.json" ]
    ];
    setupScribes = [
      {
        scKind     = "StdoutSK";
        scName     = "stdout";
        scFormat   = "ScJson"; }
      {
        scKind     = "FileSK";
        scName     = "/var/lib/cardano-node/logs/node.json";
        scFormat   = "ScJson";
        scRotation = {
          rpLogLimitBytes = 300000000;
          rpMaxAgeHours   = 24;
          rpKeepFilesNum  = 20;
        }; }
    ];
    minSeverity = "Debug";
    TracingVerbosity = "MaximalVerbosity";
    TurnOnLogMetrics = true;
    options = {
      mapBackends = {
        "cardano.node-metrics" = [ "KatipBK" ];
      };
    };
  };

in reportDeployment (rec {

  networkName = "Benchmarking, size ${toString (__length benchmarkingTopology.coreNodes)}";

  withMonitoring = false;
  withLegacyExplorer = false;

  environmentName = "bench-txgen-simple-${benchmarkingProfileName}";
  sourcesJsonOverride = ./nix/sources.bench-txgen-simple.json;

  environmentConfig = rec {
    consensusProtocol = "";           ## We're not at Shelley stage yet.

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
    generatorConfig = benchmarkingProfile.generator;
  };

  topology = benchmarkingTopology // {
    explorer = {
      imports = [
        pkgs.cardano-ops.roles.tx-generator
      ];
      services.cardano-graphql.enable = pkgs.lib.mkForce false;
      services.graphql-engine.enable = pkgs.lib.mkForce false;
      services.cardano-db-sync = {
        logConfig =
          pkgs.iohkNix.cardanoLib.defaultExplorerLogConfig
          // benchmarkingLogConfig;
      };
    };
    coreNodes = map (n : n // {
      services.cardano-node.nodeConfig =
        pkgs.globals.environmentConfig.nodeConfig
        // benchmarkingLogConfig;
    }) (benchmarkingTopology.coreNodes or []);
  };

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
})
