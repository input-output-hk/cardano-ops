rec {
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
} // (import ./static/globals.nix)
