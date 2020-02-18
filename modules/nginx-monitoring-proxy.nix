{ config, ... }:
let
  cfg = config.services.nginx-monitoring-proxy;
in with import ../nix {}; {
  options = {
    services.nginx-monitoring-proxy = {
      proxyName = lib.mkOption {
        type = lib.types.str;
        default = "localproxy";
      };

      listenPort = lib.mkOption {
        type = lib.types.int;
        default = toString globals.cardanoNodePrometheusExporterPort;
      };

      listenPath = lib.mkOption {
        type = lib.types.str;
        default = "/";
      };

      proxyPort = lib.mkOption {
        type = lib.types.int;
        default = "12797";
      };

      proxyPath = lib.mkOption {
        type = lib.types.str;
        default = "/";
      };
    };
  };
  config = {

    networking.firewall.allowedTCPPorts = [ cfg.listenPort ];

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.proxyName}" = {
        enableACME = false;
        forceSSL = false;
        listen = [
          { addr = "0.0.0.0"; port = cfg.listenPort; }
          { addr = "[::]"; port = cfg.listenPort; }
        ];
        locations."${cfg.listenPath}".proxyPass = "http://127.0.0.1:${toString cfg.proxyPort}${cfg.proxyPath}";
      };
    };
  };
}
