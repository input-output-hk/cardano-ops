pkgs: with pkgs; { nodes, name, config, ... }:
let
  cfg = config.services.metadata-server;
  hostAddr = getListenIp nodes.${name};
  inherit (import (sourcePaths.metadata-server + "/nix") {}) metadataServerHaskellPackages;
  nginxCachePath = "/var/lib/nginx/data-cache";
  nginxCacheLife = "30d";
  metadataServerPort = 8080;
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
  systemd.services.metadata-server.startLimitIntervalSec = 1800;

  systemd.services.metadata-server.serviceConfig = {
    Restart = "always";
    RestartSec = "30s";

    # Not yet available as an attribute for the Unit section in nixpkgs 20.09
    StartLimitBurst = 3;
  };
  services.metadata-server = {
    enable = true;
    port = metadataServerPort;
    #inherit (globals) environmentName;
    #environment = globals.environmentConfig;
  };
  services.cardano-postgres.enable = true;
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
      metadata-server-users root ${cfg.postgres.user}
      metadata-server-users ${cfg.user} ${cfg.postgres.user}
      metadata-server-users postgres postgres
    '';
    authentication = ''
      local all all ident map=metadata-server-users
    '';
  };
  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure the nginx caching directory is set up and accessible to nginx
  system.activationScripts = {
    nginxCacheSetup = ''
      mkdir -p "${nginxCachePath}"
      chown -R nginx:nginx /var/lib/nginx
    '';
  };
  services.nginx = {
    enable = true;
    package = nginxMetadataServer;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    preStart = ''
      [ -d "${nginxCachePath}" ] || { echo "The nginx data cache dir does not exist"; exit 1; }
      [ -w "${nginxCachePath}" ] || { echo "The nginx data cache dir is not writable by nginx"; exit 1; }
    '';
    commonHttpConfig = let
      apiKeys = import ../static/metadata-server-keys.nix;
      allowedOrigins = lib.optionals (builtins.pathExists ../static/metadata-server-allow-origins.nix) (import ../static/metadata-server-allow-origins.nix);
    in ''
      map $arg_apiKey $api_client_name {
        default "";

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (client: key: "\"${key}\" \"${client}\";") apiKeys)}
      }

      map $http_origin $origin_allowed {
        default 0;

        ${lib.concatStringsSep "\n" (map (origin: "${origin} 1;") allowedOrigins)}
      }

      log_format x-fwd '$remote_addr - $remote_user $upstream_cache_status [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd if=$not_cached;

      map $origin_allowed $origin {
        default "";
        1 $http_origin;
      }
    '' +
    # Per: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache
    # 800,000 keys ~= 100m for keys_zone
    #
    # The number of keys in use can be estimated by file count at the cache location
    # Cache size utilized is also shown in the nginx vts status page
    #
    # To fully purge the cache (where nginxCachePath = "/var/lib/nginx/data-cache" in this example):
    # systemctl stop nginx && rm -rf /var/lib/nginx/data-cache/* && systemctl start nginx
    #
    # To selectively refresh cached files from the smash origin server, from localhost run:
    # curl -kv https://127.0.0.1/api/v1/$ENDPOINT_PATH
    ''
      proxy_cache_path ${nginxCachePath} levels=1:2
                       keys_zone=metadata_server:100m max_size=2g
                       inactive=${nginxCacheLife} use_temp_path=off;

      geo $bypass_allowed {
        default 0;
        127.0.0.1 1;
      }

      map $request_method $bypass_method {
        GET $bypass_allowed;
        default 0;
      }

      map $status $not_status_404 {
        404 0;
        default 1;
      }

      map $upstream_cache_status $not_cached {
        HIT 0;
        STALE $not_status_404;
        default 1;
      }
    '';

    virtualHosts = {
      "metadata.${globals.domain}" = {
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations =
          let
          apiKeyConfig = ''
            if ($arg_apiKey = "") {
                return 401; # Unauthorized (please authenticate)
            }
            if ($api_client_name = "") {
                return 403; # Forbidden (invalid API key)
            }
          '';
          corsConfig = ''
            add_header 'Vary' 'Origin' always;
            add_header 'Access-Control-Allow-Origin' $origin always;
            add_header 'Access-Control-Allow-Methods' 'GET, PATCH, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'User-Agent,X-Requested-With,Content-Type' always;

            if ($request_method = OPTIONS) {
              add_header 'Access-Control-Max-Age' 1728000;
              add_header 'Content-Type' 'text/plain; charset=utf-8';
              add_header 'Content-Length' 0;
              return 204;
            }
          '';
          endpoints = [
            "/metadata/query"
            "/metadata"
          ];
          in lib.recursiveUpdate (lib.genAttrs endpoints (p: {
            proxyPass = "http://127.0.0.1:${toString metadataServerPort}${p}";
            extraConfig = corsConfig;
          })) {
              #${apiKeyConfig}
            "/metadata/query".extraConfig = ''
              ${corsConfig}
            '';
            "/metadata".extraConfig = ''
              ${corsConfig}
            '';
            #"/api/v1/metadata".extraConfig = ''
            #  ${corsConfig}
            #  add_header 'X-Proxy-Cache' $upstream_cache_status always;
            #  proxy_cache smash_metadata;
            #  proxy_cache_use_stale error timeout updating http_403 http_404
            #                        http_429 http_500 http_502 http_503 http_504;
            #  proxy_cache_background_update on;
            #  proxy_cache_lock on;
            #  proxy_cache_valid 404 1h;
            #  proxy_cache_valid any ${nginxCacheLife};
            #  proxy_cache_bypass $bypass_method;
            #'';
          };
      };
      "metadata-server-ip" = {
        locations = {
          "/metrics" = {
            proxyPass = "http://127.0.0.1:8080/";
          };
        };
      };
    };
  };
}
