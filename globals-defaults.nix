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

  environmentName = pkgs.globals.deploymentName;

  sourcesJsonOverride = ./nix + "/sources.${pkgs.globals.environmentName}.json";

  dnsZone = "dev.cardano.org";
  domain = "${pkgs.globals.deploymentName}.${pkgs.globals.dnsZone}";
  relaysNew = pkgs.globals.environmentConfig.relaysNew or "relays-new.${pkgs.globals.domain}";

  explorerHostName = "explorer";
  explorerForceSSL = true;
  explorerAliases = [];

  maxPrivilegedRelays = 48;

  withMonitoring = true;
  withExplorer = true;
  withLegacyExplorer = false;
  withCardanoDBExtended = true;
  withFaucet = false;
  withFaucetOptions = {};
  withSmash = false;

  initialPythonExplorerDBSyncDone = false;

  withHighCapacityMonitoring = false;
  withHighCapacityExplorer = false;
  withHighLoadRelays = false;

  environments = pkgs.iohkNix.cardanoLib.environments;

  environmentConfig = pkgs.globals.environments.${pkgs.globals.environmentName};

  deployerIp = requireEnv "DEPLOYER_IP";
  cardanoNodePort = 3001;
  cardanoNodeLegacyPort = 3000;

  cardanoNodePrometheusExporterPort = 12798;
  byronProxyPrometheusExporterPort = 12799;
  cardanoExplorerPrometheusExporterPort = 8080;
  cardanoExplorerPythonApiPrometheusExporterPort = 7001;
  netdataExporterPort = 19999;

  extraPrometheusExportersPorts = [
    pkgs.globals.cardanoNodePrometheusExporterPort
    pkgs.globals.byronProxyPrometheusExporterPort
    pkgs.globals.cardanoExplorerPrometheusExporterPort
    pkgs.globals.netdataExporterPort
  ];
}
