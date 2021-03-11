pkgs:
let
  requireEnv = name:
    let value = builtins.getEnv name;
    in if value == "" then
      abort "${name} environment variable is not set"
    else
      value;
in {

  static = import ./static;

  deploymentName = "${builtins.baseNameOf ./.}";
  deploymentPath = "$HOME/${pkgs.globals.deploymentName}";

  relayUpdateArgs = "-m 1";
  relayUpdatePeriod = "weekly";

  environmentName = pkgs.globals.deploymentName;

  topology = import (./topologies + "/${pkgs.globals.environmentName}.nix") pkgs;

  sourcesJsonOverride = ./nix + "/sources.${pkgs.globals.environmentName}.json";

  dnsZone = "dev.cardano.org";
  domain = "${pkgs.globals.deploymentName}.${pkgs.globals.dnsZone}";
  relaysNew = pkgs.globals.environmentConfig.relaysNew or "relays-new.${pkgs.globals.domain}";

  explorerHostName = "explorer.${pkgs.globals.domain}";
  explorerForceSSL = true;
  explorerAliases = [];

  withMonitoring = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSubmitApi = false;
  withFaucet = false;
  withFaucetOptions = {};
  withSmash = false;

  withMetadata = false;
  metadataHostName = "metadata.${pkgs.globals.domain}";

  initialPythonExplorerDBSyncDone = false;

  withHighCapacityMonitoring = false;
  withHighCapacityExplorer = false;
  withHighLoadRelays = false;

  environments = pkgs.iohkNix.cardanoLib.environments;

  environmentConfig =
    __trace
      "using environment:  ${pkgs.globals.environmentName}"
    pkgs.globals.environments.${pkgs.globals.environmentName};

  deployerIp = requireEnv "DEPLOYER_IP";
  cardanoNodePort = 3001;

  cardanoNodePrometheusExporterPort = 12798;
  cardanoExplorerPrometheusExporterPort = 8080;
  netdataExporterPort = 19999;

  extraPrometheusExportersPorts = [
    pkgs.globals.cardanoExplorerPrometheusExporterPort
    pkgs.globals.netdataExporterPort
  ] ++ builtins.genList (i: pkgs.globals.cardanoNodePrometheusExporterPort + i) pkgs.globals.nbInstancesPerRelay;

  alertChainDensityLow = "99";
  alertMemPoolHigh = "190";
  alertTcpHigh = "120";
  alertTcpCrit = "150";
  alertMbpsHigh = "150";
  alertMbpsCrit = "200";

  # base line number of cardano-node instance per relay,
  # can be scaled up on a per node basis by scaling up on instance type, cf roles/relays.nix.
  nbInstancesPerRelay = pkgs.globals.ec2.instances.relay-node.node.cpus / 2;

  # disk allocation for system (GBytes):
  systemDiskAllocationSize = 15;

  # disk allocation for each cardano-node instance (GBytes):
  nodeDbDiskAllocationSize = 15;

  ec2.instances = with pkgs; with iohk-ops-lib.physical.aws; {
    inherit targetEnv;
    core-node = t3a-large;
    relay-node = if globals.withHighLoadRelays
      then t3-2xlarge
      else t3a-large;
    test-node = m5ad-xlarge;
    smash = t3a-xlarge;
    faucet = t3a-large;
    metadata = t3a-medium;
    explorer = if globals.withHighCapacityExplorer
      then c5-4xlarge
      else t3a-2xlarge;
    monitoring = if globals.withHighCapacityMonitoring
      then t3-2xlargeMonitor
      else t3a-xlargeMonitor;
  };

  libvirtd.instances = with pkgs; with iohk-ops-lib.physical.libvirtd; {
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
    monitoring = if globals.withHighCapacityMonitoring
      then large
      else medium;
  };
}
