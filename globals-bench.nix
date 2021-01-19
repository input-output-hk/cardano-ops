pkgs:
with pkgs.lib;
let
  benchmarkingParamsFile = ./benchmarking-cluster-params.json;
  benchmarkingParams =
    if __pathExists benchmarkingParamsFile
    then let r = __fromJSON (__readFile benchmarkingParamsFile);
         in if __hasAttr "meta" r
            then if __hasAttr "default_profile" r.meta then r
                 else abort "${benchmarkingParamsFile} must define 'meta.default_profile':  please run 'bench reinit' to update it"
            else abort "${benchmarkingParamsFile} must define the 'meta' section:  please run 'bench reinit' to update it"
    else abort "Benchmarking requires ${toString benchmarkingParamsFile} to exist.  Please, refer to documentation.";
  benchmarkingTopologyFile =
    ./topologies + "/bench-txgen-${benchmarkingParams.meta.topology}-${toString (__length benchmarkingParams.meta.node_names)}.nix";
  benchmarkingTopology =
    if __pathExists benchmarkingTopologyFile
    then __trace "Using topology:  ${benchmarkingTopologyFile}"
      (rewriteTopologyForProfile
        (import benchmarkingTopologyFile)
        benchmarkingProfile)
    else abort "Benchmarking topology file implied by configured node count ${toString (__length benchmarkingParams.meta.node_names)} does not exist: ${benchmarkingTopologyFile}";
  ShelleyGenesisFile = ./keys/genesis.json;
  ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
  ByronGenesisFile = ./keys/byron/genesis.json;
  ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
  envConfigBase = pkgs.iohkNix.cardanoLib.environments.testnet;

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

  rewriteTopologyForProfile =
    topo: prof:
    let fixupPools = core: (core //
          { pools = if __hasAttr "pools" core && core.pools != null
                    then (if core.pools == 1 then 1 else prof.genesis.dense_pool_density)
                    else 0; });
        pooledCores = map fixupPools topo.coreNodes;
    in (topo // {
      coreNodes = map withEventlog pooledCores;
    });
  withEventlog = def: recursiveUpdate {
    services.cardano-node.eventlog = mkForce true;
    services.cardano-node.package = mkForce pkgs.cardano-node-eventlogged;
  } def;

  metadata = {
    inherit benchmarkingProfileName benchmarkingProfile benchmarkingTopology;
  };

  benchmarkingLogConfig = name: {
    defaultScribes = [
      [ "StdoutSK" "stdout" ]
      [ "FileSK"   "/var/lib/cardano-node/logs/${name}.json" ]
    ];
    setupScribes = [
      {
        scKind     = "StdoutSK";
        scName     = "stdout";
        scFormat   = "ScJson"; }
      {
        scKind     = "FileSK";
        scName     = "/var/lib/cardano-node/logs/${name}.json";
        scFormat   = "ScJson";
        scRotation = {
          rpLogLimitBytes = 300000000;
          rpMaxAgeHours   = 24;
          rpKeepFilesNum  = 20;
        }; }
    ];
    options = {
      mapBackends = {
        "cardano.node.resources" = [ "KatipBK" ];
      };
    };
  };

in (rec {

  networkName = "Benchmarking, size ${toString (__length benchmarkingTopology.coreNodes)}";

  withMonitoring = false;
  withExplorer = true;

  environmentName = "bench-txgen-${benchmarkingParams.meta.topology}-${benchmarkingProfileName}";

  sourcesJsonOverride = ./nix/sources.bench.json;

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";
    edgePort = pkgs.globals.cardanoNodePort;
    private = true;
    networkConfig = envConfigBase.networkConfig // {
      Protocol = "Cardano";
      inherit ShelleyGenesisFile ShelleyGenesisHash;
      inherit   ByronGenesisFile   ByronGenesisHash;
    };
    nodeConfig = envConfigBase.nodeConfig // {
      Protocol = "Cardano";
      inherit ShelleyGenesisFile ShelleyGenesisHash;
      inherit   ByronGenesisFile   ByronGenesisHash;
    };
    txSubmitConfig = {
      inherit (networkConfig) RequiresNetworkMagic;
      inherit ShelleyGenesisFile ByronGenesisFile;
    } // pkgs.iohkNix.cardanoLib.defaultExplorerLogConfig;

    ## This is overlaid atop the defaults in the tx-generator service,
    ## as specified in the 'cardano-benchmarking' repository.
    generatorConfig = benchmarkingProfile.generator;
  };

  topology = benchmarkingTopology // {
    explorer = {
      imports = [
        pkgs.cardano-ops.roles.tx-generator
        ({ config, ...}: {
          services.cardano-db-sync.enable = mkForce false;
          services.cardano-explorer-api.enable = mkForce false;
          services.cardano-submit-api.enable = mkForce false;
          systemd.services.cardano-explorer-api.enable = mkForce false;
        })
      ];
      services.cardano-graphql.enable = mkForce false;
      services.graphql-engine.enable = mkForce false;
      services.cardano-node.package = mkForce pkgs.cardano-node-eventlogged;
    };
    coreNodes = map (recursiveUpdate {
      services.cardano-node.nodeConfig =
        recursiveUpdate
          pkgs.globals.environmentConfig.nodeConfig
          (recursiveUpdate
            (benchmarkingLogConfig "node")
            ({
               inherit ShelleyGenesisHash ByronGenesisHash;
               TracingVerbosity = "NormalVerbosity";
               minSeverity = "Debug";
               TurnOnLogMetrics = true;
               TraceMempool     = true;
             }));
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
