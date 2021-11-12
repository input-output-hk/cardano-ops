pkgs: variant: { name, config, options, ... }:
with pkgs;

let
  maintenanceMode = false;
  cfg = config.services.cardano-db-sync;
  nodeCfg = config.services.cardano-node;
  ogmiosCfg = config.services.cardano-ogmios;
  getSrc = name: variant.${name} or sourcePaths.${name};

  cardanoNodeConfigPath = builtins.toFile "cardano-node-config.json" (builtins.toJSON nodeCfg.nodeConfig);

  dbSyncPkgs = let s = getSrc "cardano-db-sync"; in import (s + "/nix") { gitrev = s.rev; };
  inherit (dbSyncPkgs) cardanoDbSyncHaskellPackages;
  inherit (cardanoDbSyncHaskellPackages.cardano-db-sync.components.exes) cardano-db-sync;
  inherit (cardanoDbSyncHaskellPackages.cardano-node.components.exes) cardano-node;
  inherit (cardanoDbSyncHaskellPackages.cardano-db-tool.components.exes) cardano-db-tool;

  cardano-explorer-app-pkgs = import (getSrc "cardano-explorer-app");
in {
  imports = [
    cardano-ops.modules.cardano-postgres
    cardano-ops.modules.base-service
    ((sourcePaths.cardano-db-sync-service or (getSrc "cardano-db-sync")) + "/nix/nixos")
    ((getSrc "ogmios") + "/nix/nixos")
    ((getSrc "cardano-graphql") + "/nix/nixos")
    ((getSrc "cardano-rosetta") + "/nix/nixos")
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim dnsutils cardano-cli
    cardano-db-tool
  ];

  services.cardano-postgres.enable = true;
  services.postgresql = {
    ensureDatabases = [ "cexplorer" ];
    initialScript = builtins.toFile "enable-pgcrypto.sql" ''
      \connect template1
      CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA pg_catalog;
    '';
    ensureUsers = [
      {
        name = "cexplorer";
        ensurePermissions = {
          "DATABASE cexplorer" = "ALL PRIVILEGES";
          "ALL TABLES IN SCHEMA information_schema" = "SELECT";
          "ALL TABLES IN SCHEMA pg_catalog" = "SELECT";
        };
      }
    ];
    identMap = ''
      explorer-users root cexplorer
      explorer-users cardano-db-sync cexplorer
      explorer-users cardano-graphql cexplorer
      explorer-users smash cexplorer
      explorer-users dump-registered-relays-topology cexplorer
      explorer-users postgres postgres
    '';
    authentication = ''
      local all all ident map=explorer-users
    '';
  };


  services.varnish = {
    enable = globals.withSmash;
    config = ''
      vcl 4.1;

      import std;

      backend default {
        .host = "127.0.0.1";
        .port = "${toString config.services.smash.port}";
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

  services.cardano-ogmios = {
    enable = true;
    nodeConfig = cardanoNodeConfigPath;
    nodeSocketPath = nodeCfg.socketPath;
    hostAddr = "127.0.0.1";
  };

  services.graphql-engine = {
    enable = true;
  };
  services.cardano-graphql = {
    enable = true;
    inherit cardanoNodeConfigPath;
    allowListPath = cardano-explorer-app-pkgs.allowList;
    metadataServerUri = globals.environmentConfig.metadataUrl or null;
    ogmiosHost = ogmiosCfg.hostAddr;
    ogmiosPort = ogmiosCfg.port;
  } // lib.optionalAttrs (options.services.cardano-graphql ? genesisByron) {
    genesisByron = nodeCfg.nodeConfig.ByronGenesisFile;
    genesisShelley = nodeCfg.nodeConfig.ShelleyGenesisFile;
  };

  services.cardano-rosetta-server = {
    enable = true;
    topologyFilePath = iohkNix.cardanoLib.mkEdgeTopology {
      edgeNodes = map (p: p.addr) nodeCfg.producers;
      port = nodeCfg.port;
    };
    cardanoCliPath = cardano-cli + /bin/cardano-cli;
    genesisPath = nodeCfg.nodeConfig.ShelleyGenesisFile;
    cardanoNodePath = cardano-node + /bin/cardano-node;
    cardanoNodeSocketPath = nodeCfg.socketPath;
    bindAddress = "127.0.0.1";
    port = 8082;
    dbConnectionString = "socket://${cfg.postgres.user}:*@${cfg.postgres.socketdir}?db=${cfg.postgres.database}";
  };

  services.cardano-node = {
    package = cardano-node;
    allProducers = if (globals.topology.relayNodes != [])
        then [ globals.relaysNew ]
        else (map (n: n.name) globals.topology.coreNodes);
    totalMaxHeapSizeMbytes = 0.25 * config.node.memory * 1024;
  };

  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { PrometheusPort = globals.cardanoExplorerPrometheusExporterPort; };
    inherit dbSyncPkgs;
    postgres = {
      database = "cexplorer";
    };
  };

  services.smash = {
    enable = globals.withSmash;
    inherit (globals) environmentName;
    port = 3200;
    inherit dbSyncPkgs;
    # TODO: remove after https://github.com/input-output-hk/cardano-db-sync/pull/950 is tagged
    package = (dbSyncPkgs.cardanoDbSyncProject.projectFunction dbSyncPkgs.haskell-nix [
      dbSyncPkgs.cardanoDbSyncProject.projectModule
      { modules = [{packages.cardano-smash-server.flags.disable-basic-auth = true;}]; }
    ]).hsPkgs.cardano-smash-server.components.exes.cardano-smash-server;
    postgres = { inherit (cfg.postgres) port database user socketdir; };
  };

  systemd.services.cardano-db-sync.serviceConfig = {
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";
  };

  systemd.services.cardano-ogmios.serviceConfig = {
    DynamicUser = true;
    SupplementaryGroups = "cardano-node";
  };

  systemd.services.cardano-rosetta-server.serviceConfig = {
    DynamicUser = true;
    SupplementaryGroups = "cardano-node";
  };

  systemd.services.cardano-graphql = {
    environment = {
      HOME = "/run/${config.systemd.services.cardano-graphql.serviceConfig.RuntimeDirectory}";
    };
    serviceConfig = {
      RuntimeDirectory = "cardano-graphql";
      DynamicUser = true;
    };
  };

  systemd.services.graphql-engine = {
    environment = {
      HASURA_GRAPHQL_LOG_LEVEL = "warn";
    };
    # FIXME: run under cexplorer (remove sudo use)
    #serviceConfig.User = "cexplorer";
  };

  systemd.services.cardano-submit-api.serviceConfig = lib.mkIf globals.withSubmitApi {
    # Put cardano-submit-api in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
    DynamicUser = true;
  };

  services.cardano-submit-api = lib.mkIf globals.withSubmitApi {
    enable = true;
    port = 8101;
    environment = pkgs.globals.environmentConfig;
    socketPath = config.services.cardano-node.socketPath;
    inherit cardanoNodePkgs;
  };

  networking.firewall.allowedTCPPorts = [ 80 81 ];

  systemd.services.dump-registered-relays-topology = let
    excludedPools = lib.concatStringsSep ", " (map (hash: "'${hash}'") globals.static.poolsExcludeList);
    extract_relays_sql = writeText "extract_relays.sql" ''
      select array_to_json(array_agg(row_to_json(t))) from (
        select COALESCE(ipv4, dns_name) as addr, port from (
          select min(update_id) as update_id, ipv4, dns_name, port from pool_relay inner join pool_update ON pool_update.id = pool_relay.update_id inner join pool_hash ON pool_update.hash_id = pool_hash.id where ${lib.optionalString (globals.static.poolsExcludeList != []) "pool_hash.view not in (${excludedPools}) and "}(
            (ipv4 is null and dns_name NOT LIKE '% %') or ipv4 !~ '(^0\.)|(^10\.)|(^100\.6[4-9]\.)|(^100\.[7-9]\d\.)|(^100\.1[0-1]\d\.)|(^100\.12[0-7]\.)|(^127\.)|(^169\.254\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.0\.0\.)|(^192\.0\.2\.)|(^192\.88\.99\.)|(^192\.168\.)|(^198\.1[8-9]\.)|(^198\.51\.100\.)|(^203.0\.113\.)|(^22[4-9]\.)|(^23[0-9]\.)|(^24[0-9]\.)|(^25[0-5]\.)')
            group by ipv4, dns_name, port order by update_id
        ) t
      ) t;
    '';
    relays_exclude_file = builtins.toFile "relays-exclude.txt" (lib.concatStringsSep "\n" globals.static.relaysExcludeList);
  in {
    path = config.environment.systemPackages
      ++ [ config.services.postgresql.package jq netcat curl dnsutils ];
    environment = config.environment.variables;
    script = ''
      set -uo pipefail

      pingAddr() {
        index=$1
        addr=$2
        port=$3
        allAddresses=$(dig +nocookie +short -q "$addr" A)
        if [ -z "$allAddresses" ]; then
          allAddresses=$addr
        fi

        while IFS= read -r ip; do
          set +e
          PING="$(timeout 7s cardano-ping -h "$ip" -p "$port" -m $NETWORK_MAGIC -c 1 -q --json)"
          res=$?
          if [ $res -eq 0 ]; then
            echo $PING | jq -c > /dev/null 2>&1
            res=$?
          fi
          set -e
          if [ $res -eq 0 ]; then
            >&2 echo "Successfully pinged $addr:$port (on ip: $ip)"
            set +e
            geoinfo=$(curl -s -k --retry 6 https://json.geoiplookup.io/$ip)
            res=$?
            set -e
            if [ $res -eq 0 ]; then
              continent=$(echo "$geoinfo" | jq -r '.continent_name')
              country_code=$(echo "$geoinfo" | jq -r '.country_code')
              if [ "$country_code" == "US" ]; then
                state=$(echo $geoinfo | jq -r '.region')
              else
                state=$country_code
              fi
              jq -c --arg addr "$addr" --arg port "$port" \
                --arg continent "$continent" --arg state "$state" \
                '{addr: $addr, port: $port|tonumber, continent: $continent, state: $state}' \
                <<< '{}' \
                > $index-relay.json
              break
            else
              >&2 echo "Failed to retrieved goip info for $ip"
              exit $res
            fi
          else
            >&2 echo "failed to cardano-ping $addr:$port (on ip: $ip)"
          fi
        done <<< "$allAddresses"
      }

      run() {
        epoch=$(cardano-cli query tip --testnet-magic $NETWORK_MAGIC | jq .epoch)
        db_sync_epoch=$(psql -t --command="select no from epoch_sync_time order by id desc limit 1;")

        if [ $(( $epoch - $db_sync_epoch )) -gt 1 ]; then
          >&2 echo "cardano-db-sync has not catch-up with current epoch yet. Skipping."
          exit 0
        fi

        excludeList="$(sort ${relays_exclude_file})"
        cd $STATE_DIRECTORY
        rm -f *-relay.json
        i=0
        for r in $(psql -t < ${extract_relays_sql} | jq -c '.[]'); do
          addr=$(echo "$r" | jq -r '.addr')
          port=$(echo "$r" | jq -r '.port')
          allAddresses=$addr$'\n'$(dig +nocookie +short -q "$addr" A)
          excludedAddresses=$(comm -12 <(echo "$allAddresses" | sort) <(echo "$excludeList"))
          nbExcludedAddresses=$(echo $excludedAddresses | wc -w)
          if [[ $nbExcludedAddresses == 0 ]]; then
            ((i+=1))
            pingAddr $i "$addr" "$port" &
            sleep 0.5
          else
            >&2 echo "$addr excluded due to dns name or IPs being in exclude list:\n$excludedAddresses"
          fi
        done

        wait

        if test -n "$(find . -maxdepth 1 -name '*-relay.json' -print -quit)"; then
          echo "Found a total of $(find . -name '*-relay.json' -printf '.' | wc -m) relays to include in topology.json"
          find . -name '*-relay.json' -printf '%f\t%p\n' | sort -k1 -n | cut -d$'\t' -f2 | tr '\n' '\0' | xargs -r0 cat \
            | jq -n '. + [inputs]' | jq '{ Producers : . }' > topology.json
          mkdir -p relays
          mv topology.json relays/topology.json
          rm *-relay.json
        else
          echo "No relays found!!"
        fi
      }

      while true
      do
        run
        sleep 3600
      done
    '';
    # 3 failures at max within 24h:
    startLimitIntervalSec = 24 * 60 * 60;
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "registered-relays-dump";
      Restart = "always";
      RestartSec = "30s";
      StartLimitBurst = 3;
    };
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
    commonHttpConfig = let
      smashApiKeys = import ../static/smash-keys.nix;
      smashAllowedOrigins = lib.optionals (builtins.pathExists ../static/smash-allow-origins.nix) (import ../static/smash-allow-origins.nix);
    in ''
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

      map $arg_apiKey $api_client_name {
        default "";

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (client: key: "\"${key}\" \"${client}\";") smashApiKeys)}
      }

      map $http_origin $origin_allowed {
        default 0;

        ${lib.concatStringsSep "\n" (map (origin: "${origin} 1;") smashAllowedOrigins)}
      }

      map $sent_http_x_cache $loggable_varnish {
        "hit cached" 0;
        default 1;
      }

      map $origin_allowed $origin {
        default "";
        1 $http_origin;
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
      explorer = {
        default = true;
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
        in {
          "/" = {
            root = (cardano-explorer-app-pkgs.overrideScope'(self: super: {
              static = super.static.override {
                graphqlApiHost = globals.explorerHostName;
                cardanoNetwork = globals.environmentName;
                gaTrackingId = globals.static.gaTrackingId or null;
              };
            })).static;
            tryFiles = "$uri $uri/index.html /index.html";
            extraConfig = ''
              rewrite /tx/([0-9a-f]+) $http_x_forwarded_proto://$host/$lang/transaction.html?id=$1 redirect;
              rewrite /address/([0-9a-zA-Z]+) $http_x_forwarded_proto://$host/$lang/address.html?address=$1 redirect;
              rewrite /block/([0-9a-zA-Z]+) $http_x_forwarded_proto://$host/$lang/block.html?id=$1 redirect;
              rewrite /epoch/([0-9]+) $http_x_forwarded_proto://$host/$lang/epoch.html?number=$1 redirect;
              rewrite ^([^.]*[^/])$ $http_x_forwarded_proto://$host$1.html redirect;
            '';
          };
          # To avoid 502 alerts when withSubmitApi is false
          "/api/submit/tx" = lib.mkIf globals.withSubmitApi {
            proxyPass = "http://127.0.0.1:8101/api/submit/tx";
          };
          "/graphql" = {
            proxyPass = "http://127.0.0.1:3100/";
          };
          "/rosetta/" = {
            proxyPass = "http://127.0.0.1:8082/";
          };
          "/supply/total" = {
            proxyPass = "http://127.0.0.1:3100/";
            extraConfig = graphqlRewriter
              "{ ada { supply { total } } }"
              "obj.data.ada.supply.total / 1000000";
          };
          "/supply/circulating" = {
            proxyPass = "http://127.0.0.1:3100/";
            extraConfig = graphqlRewriter
              "{ ada { supply { circulating } } }"
              "obj.data.ada.supply.circulating / 1000000";
          };
        }) // {
          "/relays" = {
            root = "/var/lib/registered-relays-dump";
          };
          "/metrics2/cardano-graphql" = {
            proxyPass = "http://127.0.0.1:3100/metrics";
          };
        };
      };
    } // (lib.optionalAttrs globals.withSmash {
      smash = {
        listen = [ {
          addr = "0.0.0.0";
          port = 81;
        }];
        default = true;
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
            "/api/v1/tickers"
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
            "/api/v1/tickers".extraConfig = ''
              ${corsConfig}
              if ($request_method = GET) {
                set $arg_apiKey "bypass";
                set $api_client_name "bypass";
              }
              ${apiKeyConfig}
            '';
          };
      };
    });
  };

  # Avoid flooding (and rotating too quicky) default journal with nginx logs:
  # nginx logs: journalctl --namespace nginx
  systemd.services.nginx.serviceConfig.LogNamespace = "nginx";

  services.monitoring-exporters.extraPrometheusExporters = [
    # TODO: remove once explorer exports metrics at path `/metrics`
    {
      job_name = "explorer-exporter";
      scrape_interval = "10s";
      port = globals.cardanoExplorerPrometheusExporterPort;
      metrics_path = "/";
      labels = { alias = "${name}-exporter"; };
    }
  ] ++ lib.optional config.services.cardano-graphql.enable
    {
      job_name = "cardano-graphql-exporter";
      scrape_interval = "10s";
      metrics_path = "/metrics2/cardano-graphql";
      labels = { alias = "cardano-graphql-exporter"; };
    };
}
