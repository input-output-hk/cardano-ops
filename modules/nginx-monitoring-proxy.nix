{ config, ... }:
with import ../nix {};

{
  publicExporterPort = globals.cardanoNodePrometheusExporterPort;
  networking.firewall.allowedTCPPorts = [ publicExporterPort ];

  services.nginx = {
    enable = true;
    virtualHosts."localexporter.${globals.domain}" = {
      enableACME = false;
      forceSSL = false;
      listen = [ { addr = "0.0.0.0"; port = publicExporterPort; } ];
      locations."/".proxyPass = "http://127.0.0.1:12797/";
    };
  };
}
