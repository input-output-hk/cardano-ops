pkgs: with pkgs; { nodes, name, config, ... }:
let
  cfg = config.services.metadata-server;
  hostAddr = getListenIp nodes.${name};
  inherit (import (sourcePaths.metadata-server + "/nix") {}) metadataServerHaskellPackages;
  metadataServerPort = 8080;
  metadataWebhookPort = 8081;

  webhookKeys = import ../static/metadata-webhook-secrets.nix;
in {
  environment = {
    systemPackages = with pkgs; [
      bat fd lsof netcat ncdu ripgrep tree vim
    ];
  };
  imports = [
    cardano-ops.modules.common
    cardano-ops.modules.cardano-postgres
    (sourcePaths.metadata-server + "/nix/nixos")
  ];

  # Disallow metadata-server to restart more than 3 times within a 30 minute window
  # This ensures the service stops and an alert will get sent if there is a persistent restart issue
  # This also allows for some additional startup time before failure and restart
  #
  # If metadata-server fails and the service needs to be restarted manually before the 30 min window ends, run:
  # systemctl reset-failed metadata-server && systemctl start metadata-server
  #
  # Same as above for metadata-webhook service
  systemd.services.metadata-server.startLimitIntervalSec = 1800;
  systemd.services.metadata-webhook.startLimitIntervalSec = 1800;

  systemd.services.metadata-server.serviceConfig = {
    Restart = "always";
    RestartSec = "30s";

    # Not yet available as an attribute for the Unit section in nixpkgs 20.09
    StartLimitBurst = 3;
  };
  systemd.services.metadata-webhook.serviceConfig = {
    Restart = "always";
    RestartSec = "30s";

    # Not yet available as an attribute for the Unit section in nixpkgs 20.09
    StartLimitBurst = 3;
  };
  services.metadata-server = {
    enable = true;
    port = metadataServerPort;
  };
  services.metadata-webhook = {
    enable = true;
    port = metadataWebhookPort;
    webHookSecret = webhookKeys.webHookSecret;
    gitHubToken = webhookKeys.gitHubToken;
    postgres = {
      socketdir = config.services.metadata-server.postgres.socketdir;
      port = config.services.metadata-server.postgres.port;
      database = config.services.metadata-server.postgres.database;
      table = config.services.metadata-server.postgres.table;
      user = config.services.metadata-server.postgres.user;
      numConnections = config.services.metadata-server.postgres.numConnections;
    };
  };
  services.cardano-postgres = {
    enable = true;
    withHighCapacityPostgres = false;
  };
  services.postgresql = {
    ensureDatabases = [ "${cfg.postgres.database}" ];
    ensureUsers = [
      {
        name = "${cfg.postgres.user}";
        ensurePermissions = {
          "DATABASE ${cfg.postgres.database}" = "ALL PRIVILEGES";
        };
      }
    ];
    identMap = ''
      metadata-users root ${cfg.postgres.user}
      metadata-users ${cfg.user} ${cfg.postgres.user}
      metadata-users ${config.services.metadata-webhook.user} ${cfg.postgres.user}
      metadata-users postgres postgres
    '';
    authentication = ''
      local all all ident map=metadata-users
    '';
  };
  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure the nginx caching directory is set up and accessible to nginx
  services.nginx = {
    enable = true;
    package = nginxMetadataServer;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      #log_format x-fwd '$remote_addr - $remote_user $upstream_cache_status [$time_local] '
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd;
      #access_log syslog:server=unix:/dev/log x-fwd if=$not_cached;
    '';

    virtualHosts = {
      "${globals.metadataHostName}" = {
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations =
          let
          corsConfig = ''
            add_header 'Vary' 'Origin' always;
            add_header 'Access-Control-Allow-Methods' 'GET, PATCH, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'User-Agent,X-Requested-With,Content-Type' always;

            if ($request_method = OPTIONS) {
              add_header 'Access-Control-Max-Age' 1728000;
              add_header 'Content-Type' 'text/plain; charset=utf-8';
              add_header 'Content-Length' 0;
              return 204;
            }
          '';
          serverEndpoints = [
            "/metadata/query"
            "/metadata"
          ];
          webhookEndpoints = [
            "/webhook"
          ];
          in (lib.genAttrs serverEndpoints (p: {
            proxyPass = "http://127.0.0.1:${toString metadataServerPort}${p}";
            extraConfig = corsConfig;
          })) // (lib.genAttrs webhookEndpoints (p: {
            proxyPass = "http://127.0.0.1:${toString metadataWebhookPort}${p}";
            extraConfig = corsConfig;
          }));
      };
      "metadata-ip" = {
        locations = {
          # TODO if metadata server offers metrics
          #"/metrics/metadata" = {
          #  proxyPass = "http://127.0.0.1:8080/";
          #};
          "/metrics/varnish" = {
            proxyPass = "http://127.0.0.1:9131/metrics";
          };
        };
      };
    };
  };
}
