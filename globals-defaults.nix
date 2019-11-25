rec {
  cardanoNodePort = 3001;
  cardanoNodeLegacyPort = 3000;
  cardanoNodePrometheusExporterPort = 12798;
  byronProxyPrometheusExporterPort = 12799;
  extraPrometheusExportersPorts = [
    cardanoNodePrometheusExporterPort
    byronProxyPrometheusExporterPort
  ];
} // (import ./static/globals.nix)
