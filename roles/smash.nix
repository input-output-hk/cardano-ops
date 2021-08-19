pkgs: with pkgs; { nodes, name, config, ... }:
let
  nodeCfg = config.services.cardano-node;
  cfg = config.services.smash;
  inherit (import (sourcePaths.smash + "/nix") {}) smashHaskellPackages;
in {
  environment = {
    systemPackages = [
      bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
    ];
    variables = {
      SMASHPGPASSFILE = cfg.postgres.pgpass;
    };
  };
  imports = [
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
    (sourcePaths.smash+ "/nix/nixos")
  ];

  services.cardano-node = {
    allProducers = [ globals.relaysNew ];
    package = smashHaskellPackages.cardano-node.components.exes.cardano-node;
    totalMaxHeapSizeMbytes = 0.5 * config.node.memory * 1024;
  };

  # Disallow smash to restart more than 3 times within a 30 minute window
  # This ensures the service stops and an alert will get sent if ledger state is corrupt
  # This also allows for some additional startup time before failure and restart
  #
  # If smash fails and the service needs to be restarted manually before the 30 min window ends, run:
  # systemctl reset-failed smash && systemctl start smash
  #
  systemd.services.smash.startLimitIntervalSec = 1800;

  systemd.services.smash.serviceConfig = {
    # Put cardano-db-sync in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";

    # Not yet available as an attribute for the Unit section in nixpkgs 20.09
    StartLimitBurst = 3;
  };
  services.smash = {
    enable = true;
    inherit (globals) environmentName;
    environment = globals.environmentConfig;
    inherit (nodeCfg) socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { PrometheusPort = globals.cardanoExplorerPrometheusExporterPort; };
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
      smash-users root ${cfg.postgres.user}
      smash-users ${cfg.user} ${cfg.postgres.user}
      smash-users postgres postgres
    '';
    authentication = ''
      local all all ident map=smash-users
    '';
  };
  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.varnish = {
    enable = true;
    config = ''
      vcl 4.1;

      import std;

      backend default {
        .host = "127.0.0.1";
        .port = "3100";
      }

      acl purge {
        "localhost";
        "127.0.0.1";
      }

      sub vcl_recv {
        unset req.http.x-cache;

        # Allow PURGE from localhost
        if (req.method == "PURGE") {
          if (!std.ip(req.http.X-Real-Ip, "0.0.0.0") ~ purge) {
            return(synth(405,"Not Allowed"));
          }

          # The host is included as part of the object hash
          # We need to match the public FQDN for the purge to be successful
          set req.http.host = "smash.${globals.domain}";

          return(purge);
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

      sub vcl_backend_response {
        set beresp.ttl = 30d;
        if (beresp.status == 404) {
          set beresp.ttl = 1h;
        }
        # Default vcl_backend_response (without no-store):
          if (beresp.ttl <= 0s ||
              beresp.http.Set-Cookie ||
              beresp.http.Surrogate-control ~ "no-store" ||
              (!beresp.http.Surrogate-Control &&
              beresp.http.Cache-Control ~ "no-cache|private") ||
              beresp.http.Vary == "*") {
              /*
              * Mark as "Hit-For-Pass" for the next 2 minutes
              */
              set beresp.ttl = 120s;
              set beresp.uncacheable = true;
          }
          return (deliver);
      }
    '';
  };

  # Ensure the worker processes don't hit TCP file descriptor limits
  systemd.services.nginx.serviceConfig.LimitNOFILE = 65535;

  services.nginx = {
    enable = true;
    package = nginxSmash;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    eventsConfig = ''
      worker_connections 8192;
    '';
    commonHttpConfig = let
      apiKeys = import ../static/smash-keys.nix;
      allowedOrigins = lib.optionals (builtins.pathExists ../static/smash-allow-origins.nix) (import ../static/smash-allow-origins.nix);
    in ''
      log_format x-fwd '$remote_addr - $remote_user $sent_http_x_cache [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      map $arg_apiKey $api_client_name {
        default "";

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (client: key: "\"${key}\" \"${client}\";") apiKeys)}
      }

      map $http_origin $origin_allowed {
        default 0;

        ${lib.concatStringsSep "\n" (map (origin: "${origin} 1;") allowedOrigins)}
      }

      map $sent_http_x_cache $loggable_varnish {
        "hit cached" 0;
        default 1;
      }

      map $origin_allowed $origin {
        default "";
        1 $http_origin;
      }
    '';

    virtualHosts = {
      "smash.${globals.domain}" = {
        enableACME = config.deployment.targetEnv != "libvirtd";
        forceSSL = globals.explorerForceSSL && (config.deployment.targetEnv != "libvirtd");
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
            "/swagger.json"
            "/api/v1/metadata"
            "/api/v1/errors"
            "/api/v1/exists"
            "/api/v1/enlist"
            "/api/v1/delist"
            "/api/v1/delisted"
            "/api/v1/retired"
            "/api/v1/status"
          ];
          in lib.recursiveUpdate (lib.genAttrs endpoints (p: {
            proxyPass = "http://127.0.0.1:6081${p}";
            extraConfig = corsConfig;
          })) {
            "/api/v1/delist".extraConfig = ''
              ${corsConfig}
              ${apiKeyConfig}
            '';
            "/api/v1/enlist".extraConfig = ''
              ${corsConfig}
              ${apiKeyConfig}
            '';
            "/api/v1/metadata".extraConfig = ''
              ${corsConfig}
            '';
          };
      };
    };
  };

  # Avoid flooding (and rotating too quicky) default journal with nginx logs:
  # nginx logs: journalctl --namespace nginx
  systemd.services.nginx.serviceConfig.LogNamespace = "nginx";

  services.monitoring-exporters.extraPrometheusExporters = [
    {
      job_name = "smash-exporter";
      scrape_interval = "10s";
      port = globals.cardanoExplorerPrometheusExporterPort;
      metrics_path = "/";
      labels = { alias = "smash-exporter"; };
    }
  ];
}
