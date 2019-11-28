pkgs:
let
  requireEnv = name:
    let value = builtins.getEnv name;
    in if value == "" then
      abort "${name} environment variable is not set"
    else
      value;
in rec {

  environments = pkgs.iohkNix.cardanoLib.environments;

  environmentConfig = pkgs.globals.environments.${pkgs.globals.environmentName};

  deployerIp = requireEnv "DEPLOYER_IP";
  cardanoNodePort = 3001;
  cardanoNodeLegacyPort = 3000;

  cardanoNodePrometheusExporterPort = 12798;
  byronProxyPrometheusExporterPort = 12799;
  cardanoExplorerPrometheusExporterPort = 8080;

  extraPrometheusExportersPorts = [
    cardanoNodePrometheusExporterPort
    byronProxyPrometheusExporterPort
    cardanoExplorerPrometheusExporterPort
  ];
}
