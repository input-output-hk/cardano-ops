{ config, lib, ... }:
with import ../nix {};

let
  inherit (lib) mkForce;
  cardano-sl-pkgs = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  explorerFrontend = (import sourcePaths.cardano-sl-explorer { gitrev = sourcePaths.cardano-sl-explorer.rev; }).explorerFrontend;
  explorerLegacy = cardano-sl-pkgs.nix-tools.cexes.cardano-sl-explorer.cardano-explorer;
in {
  imports = [
    ./legacy-relay.nix
    ../modules/common.nix
    ../modules/cardano-explorer-python.nix
  ];

  # goaccess package assists in analysis of live nginx logs, ex: during DoS
  environment.systemPackages = with pkgs; [ goaccess bat fd lsof netcat ncdu ripgrep tree vim ];
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Higher than default files are required during public scraping
  systemd.services.cardano-node-legacy.serviceConfig.LimitNOFILE = 4096;
  services.cardano-node-legacy = {
    executable = "${explorerLegacy}/bin/cardano-explorer";

    # Remap to port 8101 to avoid port collision with cardano-node hard coded at port 8100
    extraCommandArgs = [ "--web-port 8101" ];

    # TODO: static or dynamic routes may need optimization
    staticRoutes = [];
    dynamicSubscribe = [
      [ "r-c-1" "r-a-3" ]
      [ "r-c-2" "r-a-2" "r-b-2" ]
      [ "p-c-1" "p-a-1" ]
    ];
  };

  # Cardano node legacy can use cardano node user def for both services to coexist
  # mkForce to the cardano node def since it already pre-exists
  users.users.cardano-node.description = mkForce "Legacy explorer";
  users.users.cardano-node.uid = mkForce 10016;
  users.groups.cardano-node.gid = mkForce 10016;
  services.explorer-python-api.enable = true;
  services.nginx = {
    enable = true;

    # Enable goaccess compatible logging config to journald
    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';
      access_log syslog:server=unix:/dev/log x-fwd;
    '';
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    virtualHosts = {
      # mkForce the explorer virtual machine config to override
      # the new explorer only nginx config
      "${globals.explorerHostName}.${globals.domain}" = mkForce {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            root = explorerFrontend;
            tryFiles = "$uri /index.html";
          };
          "/api/blocks/range/".extraConfig = "return 404;";
          "/socket.io/" = {
             proxyPass = "http://127.0.0.1:8110";
             extraConfig = ''
               proxy_http_version 1.1;
               proxy_set_header Upgrade $http_upgrade;
               proxy_set_header Connection "upgrade";
               proxy_read_timeout 86400;
             '';
          };
          "/api/" = {
             proxyPass = "http://127.0.0.1:8101";
          };
          "/api-new" = {
             extraConfig = ''
               rewrite ^/api-new/(.*)$ /api/$1 break ;
             '';
             proxyPass = "http://127.0.0.1:8100/api";
          };
          "/graphql" = {
            proxyPass = "http://127.0.0.1:3100/graphql";
          };
        };
        # Otherwise nginx serves files with timestamps unixtime+1 from /nix/store
        extraConfig = ''
          if_modified_since off;
          add_header Last-Modified "";
          etag off;
        '';
      };
      # Add an additional exporting proxy for explorer exporter
      "explorer-ip" = {
        locations = {
          "/metrics2/exporter" = {
            proxyPass = "http://127.0.0.1:8080/";
          };
        };
      };
    };
    eventsConfig = ''
      worker_connections 1024;
    '';
    appendConfig = ''
      worker_processes 4;
      worker_rlimit_nofile 2048;
    '';
  };
}
