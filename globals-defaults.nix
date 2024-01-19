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

  relayUpdateArgs = "-m 1";
  relayUpdatePeriod = "weekly";

  snapshotStatesArgs = "";

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
    a = globals.explorer13;
    b = globals.explorer13;
  };
  explorerActiveBackends = attrNames globals.explorerBackends;
  explorerRosettaActiveBackends = globals.explorerActiveBackends;
  snapshots = globals.explorer13-1;
  explorer12 = {
    cardano-explorer-app = sourcePaths."cardano-explorer-app-1.6";
    cardano-db-sync = sourcePaths.cardano-db-sync-12;
    cardano-graphql = sourcePaths."cardano-graphql-6.1";
    cardano-rosetta = sourcePaths."cardano-rosetta-1.6";
    ogmios = sourcePaths."ogmios-5.1";
    cardano-node = sourcePaths."cardano-node-1.33";
  };
  explorer12-2 = globals.explorer12 // {
    cardano-graphql = sourcePaths."cardano-graphql-6.2";
    cardano-rosetta = sourcePaths."cardano-rosetta-1.7";
  };
  explorer12-3 = globals.explorer12-2 // {
    cardano-rosetta = sourcePaths."cardano-rosetta-1.8";
    cardano-db-sync = sourcePaths.cardano-db-sync-12;
  };
  explorer13 = {
    cardano-explorer-app = sourcePaths."cardano-explorer-app-1.6";
    cardano-db-sync = sourcePaths.cardano-db-sync-13;
    cardano-graphql = sourcePaths.cardano-graphql-vasil;
    ogmios = sourcePaths."ogmios-5.5";
    cardano-rosetta = sourcePaths."cardano-rosetta-1.8";
    cardano-node = sourcePaths.cardano-node;
  };
  explorer13-1 = globals.explorer13 // {
    cardano-db-sync = sourcePaths."cardano-db-sync-13-1";
    cardano-node = sourcePaths."cardano-node-8.1.2";
  };

  explorerBackendsInContainers = false;

  withMonitoring = true;
  withExplorer = true;
  withSnapshots = false;
  withSubmitApi = false;
  withFaucet = false;
  faucetHostname = "faucet";
  withFaucetOptions = {};
  withSmash = false;

  withMetadata = false;
  metadataHostName = "metadata.${globals.domain}";

  smashDelistedPools = [];

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

  # Service monitoring exclusions:
  # 1)  db-sync and cardano-node on snapshots is restarting regularly to take snapshots
  # 2a) cardano-graphql on explorers are restarting regularly due to graphql-engine required restarts
  #  b) A higher time threshold cardano-graphql alert will be declared in this repos alert module 
  intermittentMonitoringTargets = [ "snapshots-exporter" "snapshots" "cardano-graphql-exporter" ];
  cardanoExplorerGwPrometheusExporterPort = 12699;
  netdataExporterPort = 19999;

  extraPrometheusExportersPorts = [
    globals.cardanoExplorerPrometheusExporterPort
    globals.cardanoExplorerGwPrometheusExporterPort
    globals.netdataExporterPort
    80 # cardano-graphql-exporter
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
  alertTcpHigh = 165 * globals.ec2.instances.relay-node.node.cpus;
  alertTcpCrit = 250 * globals.ec2.instances.relay-node.node.cpus;
  alertMbpsHigh = 75 * globals.ec2.instances.relay-node.node.cpus;
  alertMbpsCrit = 100 * globals.ec2.instances.relay-node.node.cpus;
  alertHighBlockUtilization = 95; # Alert if blocks are above that % full.


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

  metadataVarnishTtl = 30;

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
      metadata = r5-2xlarge;
      explorer = if globals.withHighCapacityExplorer
                 then c5-9xlarge
                 else t3a-2xlarge;
      explorer-gw = if globals.withHighCapacityExplorer
                    then c5-4xlarge
                    else t3a-xlarge;
      monitoring = if globals.withHighCapacityMonitoring
                   then t3-2xlargeMonitor
                   else t3a-xlargeMonitor;
      dense-pool = c5-2xlarge;
      snapshots = if globals.withHighCapacityExplorer
                 then r5-2xlarge
                 else t3a-2xlarge;
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
