pkgs: { config, options, name, nodes, ... }:
with pkgs;

let
  maintenanceMode = false;
  cfg = config.services.cardano-db-sync;
  nodeCfg = config.services.cardano-node;
  nodeId = config.node.nodeId;
  hostAddr = getListenIp nodes.${name};
  inherit (cardanoDbSyncHaskellPackagesOld.cardano-db-sync.components.exes) cardano-db-sync;
  inherit (cardanoDbSyncHaskellPackagesOld.cardano-db-sync-extended.components.exes) cardano-db-sync-extended;
  inherit (cardanoDbSyncHaskellPackagesOld.cardano-node.components.exes) cardano-node;
  inherit (cardanoDbSyncHaskellPackagesOld.cardano-db-tool.components.exes) cardano-db-tool;
  cardanoGraphQlPackages = import sourcePaths.cardano-graphql;
  hasura-cli-ext = cardanoGraphQlPackages.hasura-cli-ext;
  hasura-cli = cardanoGraphQlPackages.hasura-cli;
  explorer-app-extended = builtins.fetchGit {
    url = "git@github.com:input-output-hk/explorer-app-extended";
    rev = "8281d0778c7321163ad135b6b874d8c9bbe1eaaa";
    ref = "fix-nix-build";
  };
in {
  nixpkgs.overlays = [ (self: super: {
    hasura-cli = hasura-cli;
  }) ];
  imports = [
    (sourcePaths.cardano-graphql + "/nix/nixos")
    (sourcePaths.cardano-db-sync-old + "/nix/nixos")
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
    "${explorer-app-extended}/nix/api-server.nix"
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim dnsutils cardano-cli
    cardano-db-tool
  ];

  services.cardano-postgres.enable = true;
  services.castalia = {
    enable = true;
    network = "testnet";
    inherit (import ../static/castalia.nix) gaTrackingId gtmTrackingId;
    apiHost = globals.explorerIogHostName;
    cardanoLib = iohkNix.cardanoLib;
  };
  systemd.services.castalia-api-server.environment = (import ../static/castalia.nix).api-server;
  systemd.services.castalia-data-collector.environment = (import ../static/castalia.nix).data-collector;
  # TODO: use an env file and nixops secrets

  services.postgresql = {
    ensureDatabases = [ "explorer_backend" ];
    ensureUsers = [
      {
        name = "explorer_backend";
        ensurePermissions = {
          "DATABASE explorer_backend" = "ALL PRIVILEGES";
        };
      }
    ];
    identMap = ''
      explorer-users root explorer_backend
      explorer-users explorer_backend explorer_backend
      explorer-users postgres postgres
    '';
    authentication = ''
      local all all ident map=explorer-users
    '';
  };

  services.graphql-engine = {
    enable = true;
    dbUser = "explorer_backend";
    db = "explorer_backend";
  };
  # TODO DELETE ME ONCE WORKING
  services.cardano-graphql = {
    dbUser = "explorer_backend";
    db = "explorer_backend";
    enable = false;
    genesisByron = nodeCfg.nodeConfig.ByronGenesisFile;
    genesisShelley = nodeCfg.nodeConfig.ShelleyGenesisFile;
    allowListPath = cardano-explorer-app-pkgs.allowList;
    cardanoNodeSocketPath = nodeCfg.socketPath;
    cardanoNodeConfigPath = builtins.toFile "cardano-node-config.json" (builtins.toJSON nodeCfg.nodeConfig);
    metadataServerUri = globals.environmentConfig.metadataUrl or null;
  };

  services.cardano-node = {
    package = cardano-node;
    totalMaxHeapSizeMbytes = 0.4375 * config.node.memory * 1024;
  };

  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    user = "explorer_backend";
    extended = globals.withCardanoDBExtended;
    package = if globals.withCardanoDBExtended
      then cardano-db-sync-extended
      else cardano-db-sync;
    postgres = {
      database = "explorer_backend";
    };
  };

  systemd.services.cardano-db-sync.serviceConfig = {
    # Put cardano-db-sync in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";
  };

  systemd.services.graphql-engine = {
    environment = {
      HASURA_GRAPHQL_LOG_LEVEL = "warn";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };

  services.nginx = {
    enable = true;
    package = nginxExplorer;
    eventsConfig = ''
      worker_connections 4096;
    '';
    appendConfig = ''
      worker_rlimit_nofile 16384;
    '';
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" "$http_accept_language" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd;
      limit_req_zone $binary_remote_addr zone=apiPerIP:100m rate=1r/s;
      limit_req_status 429;
      map $http_accept_language $lang {
              default en;
              ~de de;
              ~ja ja;
      }

      # set search paths for pure Lua external libraries (';;' is the default path):
      lua_package_path '${luajit}/share/lua/${luajit.lua.luaversion}/?.lua;${luajit}/lib/lua/${luajit.lua.luaversion}/?.lua;;';
      # set search paths for Lua external libraries written in C (can also use ';;'):
      lua_package_cpath '${luajit}/lib/lua/${luajit.lua.luaversion}/?.so;${luajit}/share/lua/${luajit.lua.luaversion}/?.so;;';
      init_by_lua_block {
        json = require "cjson"
      }
    '';
    virtualHosts = {
      "${globals.explorerIogHostName}" = {
        serverAliases = globals.explorerAliases;
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations = (if maintenanceMode then {
          "/" = let
            maintenanceFile = __toFile "maintenance.html" ''
              <!doctype html>
              <title>Site Maintenance</title>
              <style>
                body { text-align: center; padding: 150px; }
                h1 { font-size: 50px; }
                body { font: 20px Helvetica, sans-serif; color: #333; }
                article { display: block; text-align: left; width: 650px; margin: 0 auto; }
                a { color: #dc8100; text-decoration: none; }
                a:hover { color: #333; text-decoration: none; }
              </style>

              <article>
                  <h1>We&rsquo;ll be back soon!</h1>
                  <div>
                      <p>Sorry for the inconvenience, but we&rsquo;re performing some routine maintenance on the explorer at the moment. We&rsquo;ll be back online shortly!</p>
                      <p>&mdash; IOHK DevOps</p>
                  </div>
              </article>
            '';
            rootDir = pkgs.runCommand "nginx-root-dir" {} ''
              mkdir $out
              cd $out
              cp ${maintenanceFile} index.html;
            '';
          in {
            extraConfig = ''
              etag off;
              add_header etag "\"${builtins.substring 11 32 rootDir}\"";
              root ${rootDir};
            '';
            tryFiles = "$uri /index.html";
          };
        } else
          let graphqlRewriter = query: postProcessing: ''
            rewrite_by_lua_block {
                ngx.req.read_body()
                ngx.req.set_header("Content-Type", "application/json")
                ngx.req.set_method(ngx.HTTP_POST)
                ngx.req.set_uri("/graphql")
                ngx.req.set_body_data("{\"query\":\"${query}\"}")
              }
              header_filter_by_lua_block {
                ngx.header.content_length = nil
              }
              body_filter_by_lua_block {
                local chunk, eof = ngx.arg[1], ngx.arg[2]
                local buf = ngx.ctx.buf
                if eof then
                  if buf then
                    local obj = json.decode(buf .. chunk)
                    ngx.arg[1] = ${postProcessing}
                  end
                else
                  if buf then
                    ngx.ctx.buf = buf .. chunk
                  else
                    ngx.ctx.buf = chunk
                  end
                  ngx.arg[1] = nil
                end
              }
            '';
            oauthProxyConfig = ''
              #auth_request /oauth2/auth;
              error_page 401 = /oauth2/sign_in;

              # pass information via X-User and X-Email headers to backend,
              # requires running with --set-xauthrequest flag
              auth_request_set $user   $upstream_http_x_auth_request_user;
              auth_request_set $email  $upstream_http_x_auth_request_email;
              proxy_set_header X-User  $user;
              proxy_set_header X-Email $email;

              # if you enabled --cookie-refresh, this is needed for it to work with auth_request
              auth_request_set $auth_cookie $upstream_http_set_cookie;
              add_header Set-Cookie $auth_cookie;
            '';
        in {
          "/" = {
            root = "${config.services.castalia.package}/web-app";
            tryFiles = "$uri $uri/index.html /index.html";
            extraConfig = ''
              rewrite /tx/([0-9a-f]+) /$lang/transaction.html?id=$1 redirect;
              rewrite /address/([0-9a-zA-Z]+) /$lang/address.html?address=$1 redirect;
              rewrite /block/([0-9a-zA-Z]+) /$lang/block.html?id=$1 redirect;
              rewrite /epoch/([0-9]+) /$lang/epoch.html?number=$1 redirect;
              rewrite ^([^.]*[^/])$ $1.html redirect;
              ${oauthProxyConfig}
            '';
          };
          "/graphql" = {
            proxyPass = "http://127.0.0.1:3100/";
          };
        });
      };
      "explorer-ip" = {
        locations = {
          "/metrics2/exporter" = {
            proxyPass = "http://127.0.0.1:8080/";
          };
          "/metrics2/cardano-graphql" = {
            proxyPass = "http://127.0.0.1:3100/metrics";
          };
        };
      };
    };
  };
  services.oauth2_proxy = {
    enable = true;
    inherit (globals.static.oauth) clientID clientSecret cookie;
    provider = "google";
    email.domains = [ "iohk.io" ];
    nginx.virtualHosts = [ globals.explorerIogHostName ];
    setXauthrequest = true;
  };

  # Avoid flooding (and rotating too quicky) default journal with nginx logs:
  # nginx logs: journalctl --namespace nginx
  systemd.services.nginx.serviceConfig.LogNamespace = "nginx";

  services.monitoring-exporters.extraPrometheusExporters = [
    # TODO: remove once explorer exports metrics at path `/metrics`
    {
      job_name = "explorer-exporter";
      scrape_interval = "10s";
      metrics_path = "/metrics2/exporter";
      labels = { alias = "explorer-exporter"; };
    }
    {
      job_name = "cardano-graphql-exporter";
      scrape_interval = "10s";
      metrics_path = "/metrics2/cardano-graphql";
      labels = { alias = "cardano-graphql-exporter"; };
    }
  ];
}
