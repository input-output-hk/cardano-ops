pkgs: with pkgs; { nodes, name, config, ... }:
let
  cfg = config.services.metadata-server;
  hostAddr = getListenIp nodes.${name};
  metadataServerPort = 8080;
  metadataWebhookPort = 8081;
  webhookKeys = import ../static/metadata-webhook-secrets.nix;
  metadataSyncInfo = import ../static/metadata-sync-info.nix;

  # The maximum POST size allowed for a metadata/query body payload
  maxPostSizeBodyKb = 64;

  # The maximum cacheable POST size before varnish will disconnect and cause nginx to 502
  maxPostSizeCachableKb = 100;
in {
  environment = {
    systemPackages = with pkgs; [
      bat fd lsof netcat ncdu ripgrep tree vim
    ];
  };
  imports = [
    cardano-ops.modules.common
    cardano-ops.modules.cardano-postgres
    (sourcePaths.offchain-metadata-tools + "/nix/nixos")
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

  systemd.services.metadata-server = {
    environment = {
      GHCRTS = "-M${toString (config.node.memory * 1024 / 2)}M";
    };
    serviceConfig = {
      Restart = "always";
      RestartSec = "30s";

      # Not yet available as an attribute for the Unit section in nixpkgs 20.09
      StartLimitBurst = 3;

      # Limit memory and runtime until a memory leak is addressed (keep memory for varnish)
      MemoryMax = "${toString (128 + config.node.memory * 1024 / 2)}M";
      RuntimeMaxSec = 4 * 60 * 60;
    };
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
    postgres.numConnections = config.node.cpus;
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
  services.metadata-sync = {
    enable = true;
    postgres = {
      inherit (config.services.metadata-server.postgres) socketdir port database table user numConnections;
    };

    git = {
      repositoryUrl = metadataSyncInfo.gitUrl;
      metadataFolder = metadataSyncInfo.gitMetadataFolder;
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
      metadata-users ${config.services.metadata-sync.user} ${cfg.postgres.user}
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

  services.varnish = {
    enable = true;
    extraModules = [ pkgs.varnishPackages.modules ];
    extraCommandLine = "-t ${toString (globals.metadataVarnishTtl * 60)} -s malloc,${toString (config.node.memory * 1024 / 3)}M";
    config = ''
      vcl 4.1;

      import std;
      import bodyaccess;

      backend default {
        .host = "127.0.0.1";
        .port = "${toString metadataServerPort}";
      }

      acl purge {
        "localhost";
        "127.0.0.1";
      }

      sub vcl_recv {
        unset req.http.X-Body-Len;
        unset req.http.x-cache;

        # Allow PURGE from localhost
        if (req.method == "PURGE") {
          if (!std.ip(req.http.X-Real-Ip, "0.0.0.0") ~ purge) {
            return(synth(405,"Not Allowed"));
          }

          # The host is included as part of the object hash
          # We need to match the public FQDN for the purge to be successful
          set req.http.host = "${globals.metadataHostName}";
        }

        # Allow POST caching
        # PURGE also needs to hash the body to obtain a correct object hash to purge
        if (req.method == "POST" || req.method == "PURGE") {
          # Caches the body which enables POST retries if needed
          std.cache_req_body(${toString maxPostSizeCachableKb}KB);
          set req.http.X-Body-Len = bodyaccess.len_req_body();

          if ((std.integer(req.http.X-Body-Len, ${toString (1024 * maxPostSizeCachableKb)}) > ${toString (1024 * maxPostSizeBodyKb)}) ||
              (req.http.X-Body-Len == "-1")) {
            return(synth(413, "Payload Too Large"));
          }

          if (req.method == "PURGE") {
            return(purge);
          }
          return(hash);
        }
      }

      sub vcl_hash {
        # For caching POSTs, hash the body also
        if (req.http.X-Body-Len) {
          bodyaccess.hash_req_body();
        }
        else {
          hash_data("");
        }
      }

      sub vcl_hit {
        set req.http.x-cache = "hit";
      }

      sub vcl_miss {
        set req.http.x-cache = "miss";
      }

      sub vcl_pass {
        set req.http.x-cache = "pass";
      }

      sub vcl_pipe {
        set req.http.x-cache = "pipe";
      }

      sub vcl_synth {
        set req.http.x-cache = "synth synth";
        set resp.http.x-cache = req.http.x-cache;
      }

      sub vcl_deliver {
        if (obj.uncacheable) {
          set req.http.x-cache = req.http.x-cache + " uncacheable";
        }
        else {
          set req.http.x-cache = req.http.x-cache + " cached";
        }
        set resp.http.x-cache = req.http.x-cache;
      }

      sub vcl_backend_fetch {
        if (bereq.http.X-Body-Len) {
          set bereq.method = "POST";
        }
      }

      sub vcl_backend_response {
        if (beresp.status == 404) {
          set beresp.ttl = ${toString (2 * globals.metadataVarnishTtl / 3)}m;
        }
        call vcl_builtin_backend_response;
        return (deliver);
      }
    '';
  };

  # Ensure the worker processes don't hit TCP file descriptor limits
  systemd.services.nginx.serviceConfig.LimitNOFILE = 65535;

  services.nginx = {
    enable = true;
    package = nginxMetadataServer;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    eventsConfig = ''
      worker_connections 8192;
    '';
    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user $sent_http_x_cache [$time_local] '
                       '"$request" $status $request_length $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd if=$loggable;

      limit_req_zone $binary_remote_addr zone=metadataQueryPerIP:100m rate=30r/s;
      limit_req_status 429;
      server_names_hash_bucket_size 128;

      map $sent_http_x_cache $loggable_varnish {
        default 1;
        "hit cached" 0;
      }

      map $request_uri $loggable {
        /status/format/prometheus 0;
        default $loggable_varnish;
      }

      map $request_method $upstream_location {
        GET     127.0.0.1:6081;
        default 127.0.0.1:${toString metadataServerPort};
      }
    '';

    virtualHosts = {
      "${globals.metadataHostName}" = {
        enableACME = config.deployment.targetEnv != "libvirtd";
        forceSSL = globals.explorerForceSSL && (config.deployment.targetEnv != "libvirtd");
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
          in (lib.recursiveUpdate (lib.genAttrs serverEndpoints (p: {
            proxyPass = "http://$upstream_location";
            extraConfig = corsConfig;
           })) {
           # Uncomment to add varnish caching for all request on `/metadata/query` endpoint:
           # "/metadata/query".proxyPass = "http://127.0.0.1:6081";
           "/metadata/query".extraConfig = ''
             limit_req zone=metadataQueryPerIP burst=20 nodelay;
             ${corsConfig}
           '';
           "/metadata/healthcheck".extraConfig = ''
              add_header Content-Type text/plain;
              return 200 'OK';
           '';
          }) // (lib.genAttrs webhookEndpoints (p: {
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
        };
      };
    };
  };

  # Avoid flooding (and rotating too quicky) default journal with nginx logs.
  # nginx logs: journalctl --namespace nginx
  systemd.services.nginx.serviceConfig.LogNamespace = "nginx";

  services.monitoring-exporters.extraPrometheusExporters = [
    #{
    #  job_name = "metadata";
    #  scrape_interval = "10s";
    #  metrics_path = "/metrics/metadata";
    #}
  ];

  # If nss-systemd stops resolving dynamic users properly, the services will stop; this will prevent that.
  users = {
    groups = {
      metadata-server = {};
      metadata-sync = {};
      metadata-webhook = {};
    };

    users = let
      mkUser = name: {
        group = "metadata-${name}";
        isSystemUser = true;
      };
    in {
      metadata-server = mkUser "server";
      metadata-sync = mkUser "sync";
      metadata-webhook = mkUser "webhook";
    };
  };
}
