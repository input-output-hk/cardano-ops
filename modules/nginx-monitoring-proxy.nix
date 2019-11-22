{ config, ... }:
with import ../nix {};

{
  networking.firewall.allowedTCPPorts = [ 12798 ];

  services.nginx = {
    enable = true;
    virtualHosts."localexporter.${globals.domain}" = {
      enableACME = false;
      forceSSL = false;
      listen = [ { addr = "0.0.0.0"; port = 12798; } ];
      locations."/".proxyPass = "http://127.0.0.1:12797/";
    };
  };
}
