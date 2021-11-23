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
    ./topologies + "/bench-${benchmarkingParams.meta.topology}-${toString (__length benchmarkingParams.meta.node_names)}.nix";
  benchmarkingTopology =
    if __pathExists benchmarkingTopologyFile
    then __trace "Using topology:  ${benchmarkingTopologyFile}"
      (rewriteTopologyForProfile
        (import benchmarkingTopologyFile)
        benchmarkingProfile)
    else abort "Benchmarking topology file implied by configured node count ${toString (__length benchmarkingParams.meta.node_names)} does not exist: ${benchmarkingTopologyFile}";
  AlonzoGenesisFile  = ./keys/alonzo-genesis.json;
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
    in (topo // {
      coreNodes = map fixupPools topo.coreNodes;
    });

  metadata = {
    inherit benchmarkingProfileName benchmarkingProfile benchmarkingTopology;
  };

  inherit (import ./globals-bench-common.nix { inherit pkgs benchmarkingProfile; })
    mkNodeOverlay;

in (rec {
  inherit benchmarkingProfile;

  networkName = "Benchmarking, size ${toString (__length benchmarkingTopology.coreNodes)}";

  withExplorer = false;
  withMonitoring = false;
  explorerBackends = {};
  explorerActiveBackends = [];

  environmentName = "bench-${benchmarkingParams.meta.topology}-${benchmarkingProfileName}";

  sourcesJsonOverride = ./nix/sources.bench.json;

  relaysNew = "relays-new.${pkgs.globals.domain}";

  environmentConfig = rec {
    relays = "relays.${pkgs.globals.domain}";

    edgePort = pkgs.globals.cardanoNodePort;
    private = true;
    networkConfig = (removeAttrs envConfigBase.networkConfig ["AlonzoGenesisHash"]) // {
      Protocol = "Cardano";
      inherit  AlonzoGenesisFile;
      inherit ShelleyGenesisFile ShelleyGenesisHash;
      inherit   ByronGenesisFile   ByronGenesisHash;
    };
    nodeConfig = (removeAttrs envConfigBase.nodeConfig ["AlonzoGenesisHash"]) // {
      Protocol = "Cardano";
      inherit  AlonzoGenesisFile;
      inherit ShelleyGenesisFile ShelleyGenesisHash;
      inherit   ByronGenesisFile   ByronGenesisHash;
    } // {
      shelley =
        { TestShelleyHardForkAtEpoch = 0;
        };
      allegra =
        { TestShelleyHardForkAtEpoch = 0;
          TestAllegraHardForkAtEpoch = 0;
        };
      mary =
        { TestShelleyHardForkAtEpoch = 0;
          TestAllegraHardForkAtEpoch = 0;
          TestMaryHardForkAtEpoch    = 0;
        };
      alonzo =
        { TestShelleyHardForkAtEpoch = 0;
          TestAllegraHardForkAtEpoch = 0;
          TestMaryHardForkAtEpoch    = 0;
          TestAlonzoHardForkAtEpoch  = 0;
        };
    }.${pkgs.globals.environmentConfig.generatorConfig.era};
    txSubmitConfig = {
      inherit (networkConfig) RequiresNetworkMagic;
      inherit AlonzoGenesisFile ShelleyGenesisFile ByronGenesisFile;
    } // pkgs.iohkNix.cardanoLib.defaultExplorerLogConfig;

    ## This is overlaid atop the defaults in the tx-generator service,
    ## as specified in the 'cardano-node' repository.
    generatorConfig = benchmarkingProfile.generator;
  };

  topology = {
    relayNodes = map
      (recursiveUpdate
        (mkNodeOverlay
          ## 1. nixos machine overlay
          {
            ## XXX: assumes we have `explorer` as our only relay.
            imports = [
              pkgs.cardano-ops.roles.tx-generator
              # ({ config, ...}: {
              # })
            ];
            systemd.services.dump-registered-relays-topology.enable = mkForce false;
          }
          ## 2. cardano-node service config overlay
          {
            ## This allows tracking block contents on the explorer.
            TraceBlockFetchProtocol = true;
          }))
      (benchmarkingTopology.relayNodes or []);
    coreNodes = map
      (recursiveUpdate
        (mkNodeOverlay
          ## 1. nixos machine overlay
          {
            stakePool = true;
          }
          ## 2. cardano-node service config overlay
          {
          }
        )) (benchmarkingTopology.coreNodes or []);
  };

  ec2 = with pkgs.iohk-ops-lib.physical.aws;
    {
      instances = {
        core-node = c5-2xlarge;
        relay-node = c5-2xlarge;
      };
      credentials = {
        accessKeyIds = {
          IOHK = "dev-deployer";
          dns = "dev-deployer";
        };
      };
    };
})
