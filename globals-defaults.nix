pkgs: with pkgs; with lib;
let
  requireEnv = name:
    let value = builtins.getEnv name;
    in if value == "" then
      abort "${name} environment variable is not set"
    else
      value;
in {

  static = import ./static pkgs;
  overlay = (_:_: {});

  deploymentName = "${builtins.baseNameOf ./.}";
  deploymentPath = "$HOME/${globals.deploymentName}";

  registeredRelaysDumpPeriod = "hourly";
  relayUpdateArgs = "-m 1";
  relayUpdatePeriod = "weekly";

  dbSyncSnapshotArgs = "";

  dbSyncSnapshotPeriod = "10d";

  environmentName = globals.deploymentName;

  topology = import (./topologies + "/${globals.deploymentName}.nix") pkgs;

  sourcesJsonOverride = ./nix + "/sources.${globals.environmentName}.json";

  dnsZone = "dev.cardano.org";
  domain = "${globals.deploymentName}.${globals.dnsZone}";
  relaysNew = if (globals.deploymentName == globals.environmentName)
    then globals.environmentConfig.relaysNew or "relays.${globals.domain}"
    else "relays.${globals.domain}";

  explorerHostName = "explorer.${globals.domain}";
  explorerForceSSL = true;
  explorerAliases = [];
  explorerBackends = {
    a = globals.explorer11;
    b = globals.explorer11;
  };
  explorerActiveBackends = attrNames globals.explorerBackends;
  explorerDbSnapshots = globals.explorer11;
  explorer11 = {
    cardano-db-sync = sourcePaths.cardano-db-sync-11;
    cardano-graphql = sourcePaths."cardano-graphql-5.1";
    cardano-explorer-app = sourcePaths."cardano-explorer-app-1.6";
    cardano-rosetta = sourcePaths."cardano-rosetta-1.4";
  };
  explorerBackendsInContainers = false;

  withMonitoring = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSubmitApi = false;
  withFaucet = false;
  faucetHostname = "faucet";
  withFaucetOptions = {};
  withSmash = false;

  withMetadata = false;
  metadataHostName = "metadata.${globals.domain}";

  initialPythonExplorerDBSyncDone = false;

  withHighCapacityMonitoring = false;
  withHighCapacityExplorer = false;
  withHighLoadRelays = false;

  environments = iohkNix.cardanoLib.environments;

  environmentConfig =
    __trace
      "using environment:  ${globals.environmentName}"
    globals.environments.${globals.environmentName};

  environmentVariables = optionalAttrs (builtins.pathExists ./globals.nix) (
    let
      genesisFile = globals.environmentConfig.nodeConfig.ShelleyGenesisFile;
      genesis =  builtins.fromJSON (builtins.readFile (if (builtins.pathExists genesisFile)
       then genesisFile
       # Use mainnet genesis as template to set network parameters if genesis does not exist yet:
       else iohkNix.cardanoLib.environments.mainnet.nodeConfig.ShelleyGenesisFile));
      bftNodes = filter (c: !c.stakePool) globals.topology.coreNodes;
      stkNodes = filter (c: c.stakePool) globals.topology.coreNodes;
    in rec {
      ENVIRONMENT = globals.environmentName;
      RELAYS = globals.relaysNew;
      DOMAIN = globals.domain;

      CORE_NODES = toString (map (x: x.name) globals.topology.coreNodes);
      NB_CORE_NODES = toString (builtins.length globals.topology.coreNodes);
      BFT_NODES = toString (map (x: x.name) bftNodes);
      NB_BFT_NODES = toString (builtins.length bftNodes);
      POOL_NODES = toString (map (x: x.name) stkNodes);
      NB_POOL_NODES = toString (builtins.length stkNodes);

      GENESIS_PATH = toString genesisFile;
      # Network parameters.
      NETWORK_MAGIC = toString genesis.networkMagic;
      EPOCH_LENGTH = toString genesis.epochLength;
      SLOT_LENGTH = toString genesis.slotLength;
      K = toString genesis.securityParam;
      F = toString genesis.activeSlotsCoeff;
      MAX_SUPPLY = toString genesis.maxLovelaceSupply;
    } // (optionalAttrs (builtins.pathExists genesisFile) {
      SYSTEM_START = genesis.systemStart;
      # End: Network parameters.
    }) // (optionalAttrs (globals.environmentConfig.nodeConfig ? ByronGenesisFile) {
      BYRON_GENESIS_PATH = toString globals.environmentConfig.nodeConfig.ByronGenesisFile;
    }));

  deployerIp = requireEnv "DEPLOYER_IP";
  cardanoNodePort = 3001;

  cardanoNodePrometheusExporterPort = 12798;
  cardanoExplorerPrometheusExporterPort = 12698;
  cardanoExplorerGwPrometheusExporterPort = 12699;
  netdataExporterPort = 19999;

  extraPrometheusExportersPorts = [
    globals.cardanoExplorerPrometheusExporterPort
    globals.cardanoExplorerGwPrometheusExporterPort
    globals.netdataExporterPort
  ] ++ builtins.genList (i: globals.cardanoNodePrometheusExporterPort + i) globals.nbInstancesPerRelay;

  extraPrometheusBlackboxExporterModules = {
    https_explorer_post_2xx = {
      prober = "http";
      timeout = "10s";
      http = {
        fail_if_not_ssl = true;
        method = "POST";
        headers = {
          Content-Type = "application/json";
        };
        body = ''{"query": "{\n  ada {\n    supply {\n      total\n    }\n  }\n}\n"}'';
      };
    };
  };

  alertChainDensityLow = "99";
  alertMemPoolHigh = "190";
  alertTcpHigh = 300 * pkgs.globals.nbInstancesPerRelay;
  alertTcpCrit = 350 * pkgs.globals.nbInstancesPerRelay;
  alertMbpsHigh = 150 * pkgs.globals.nbInstancesPerRelay;
  alertMbpsCrit = 200 * pkgs.globals.nbInstancesPerRelay;


  # Minimal memory and cpu requirements for cardano-node:
  minCpuPerInstance = 2;
  minMemoryPerInstance = 8;
  # base line number of cardano-node instance per relay,
  # can be scaled up on a per node basis by scaling up on instance type, cf roles/relays.nix.
  nbInstancesPerRelay = with globals; with globals.ec2.instances.relay-node.node;
    let idealNbInstances = min (cpus / minCpuPerInstance) (topology-lib.roundToInt (memory / minMemoryPerInstance));
      actualNbInstances = max 1 idealNbInstances;
      cpusPerInstance = cpus / actualNbInstances;
      memoryPerInstance = memory / actualNbInstances;
      configMessage = "~ ${toString cpusPerInstance} CPUs and ${toString memoryPerInstance}G memory per instance.";
    in builtins.trace (if idealNbInstances != actualNbInstances
      then "WARNING: selected AWS instance for relays is not sufficient to satisfy minimal CPUs (${toString minCpuPerInstance}) or memory (${toString minMemoryPerInstance}G) requirements. Will use ${configMessage}"
      else "Using ${toString actualNbInstances} cardano-node instances per relay: ${configMessage}")
      actualNbInstances;

  # disk allocation for system (GBytes):
  systemDiskAllocationSize = 15;

  # disk allocation for each cardano-node instance (GBytes):
  nodeDbDiskAllocationSize = 15;

  ec2.instances = with iohk-ops-lib.physical.aws;
    ## Can't run a node on anything smaller:
    ##
    let node-baseline = t3a-large;
    in {
      inherit targetEnv;
      core-node = node-baseline;
      relay-node = if globals.withHighLoadRelays
                   then t3-2xlarge
                   else node-baseline;
      test-node = m5ad-xlarge;
      smash = t3a-xlarge;
      faucet = node-baseline;
      metadata = t3a-2xlarge;
      explorer = if globals.withHighCapacityExplorer
                 then c5-9xlarge
                 else t3a-xlarge;
      explorer-gw = if globals.withHighCapacityExplorer
                    then t3a-2xlarge
                    else t3a-xlarge;
      monitoring = if globals.withHighCapacityMonitoring
                   then t3-2xlargeMonitor
                   else t3a-xlargeMonitor;
      dense-pool = c5-2xlarge;
    };

  libvirtd.instances = with iohk-ops-lib.physical.libvirtd; {
    inherit targetEnv;
    core-node = medium;
    relay-node = if globals.withHighLoadRelays
      then medium
      else large;
    test-node = large;
    smash = medium;
    faucet = medium;
    metadata = medium;
    explorer = if globals.withHighCapacityExplorer
      then large
      else medium;
    explorer-gw = small;
    monitoring = if globals.withHighCapacityMonitoring
      then large
      else medium;
  };
}
