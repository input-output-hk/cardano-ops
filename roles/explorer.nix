pkgs: { config, options, name, nodes, ... }:
with pkgs;

let
  maintenanceMode = false;
  cfg = config.services.cardano-db-sync;
  nodeCfg = config.services.cardano-node;
  nodeId = config.node.nodeId;
  hostAddr = getListenIp nodes.${name};
  inherit (cardanoDbSyncHaskellPackages.cardano-db-sync.components.exes) cardano-db-sync;
  inherit (cardanoDbSyncHaskellPackages.cardano-db-sync-extended.components.exes) cardano-db-sync-extended;
  inherit (cardanoDbSyncHaskellPackages.cardano-node.components.exes) cardano-node;
  inherit (cardanoDbSyncHaskellPackages.cardano-db-tool.components.exes) cardano-db-tool;
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-graphql + "/nix/nixos")
    (sourcePaths.cardano-rest + "/nix/nixos")
    (sourcePaths.cardano-db-sync + "/nix/nixos")
    (sourcePaths.cardano-rosetta + "/nix/nixos")
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim dnsutils cardano-cli
    cardano-db-tool
  ];
  services.cardano-postgres.enable = true;
  services.postgresql = {
    ensureDatabases = [ "cexplorer" ];
    ensureUsers = [
      {
        name = "cexplorer";
        ensurePermissions = {
          "DATABASE cexplorer" = "ALL PRIVILEGES";
        };
      }
    ];
    identMap = ''
      explorer-users root cexplorer
      explorer-users cexplorer cexplorer
      explorer-users postgres postgres
    '';
    authentication = ''
      local all all ident map=explorer-users
    '';
  };

  services.graphql-engine.enable = true;
  services.cardano-graphql = {
    enable = true;
    genesisByron = nodeCfg.nodeConfig.ByronGenesisFile;
    genesisShelley = nodeCfg.nodeConfig.ShelleyGenesisFile;
    allowListPath = cardano-explorer-app-pkgs.allowList;
    cardanoNodeSocketPath = nodeCfg.socketPath;
    # Default value is for mainnet. bypassing for other env (thus may throw if not fully sync):
    currentEraFirstSlot = lib.mkIf (globals.environmentName != "mainnet") 1;
  };

  services.cardano-rosetta-server = {
    enable = true;
    topologyFilePath = nodeCfg.topology;
    cardanoCliPath = cardano-cli + /bin/cardano-cli;
    genesisPath = nodeCfg.nodeConfig.ShelleyGenesisFile;
    cardanoNodePath = cardano-node + /bin/cardano-node;
    cardanoNodeSocketPath = nodeCfg.socketPath;
    bindAddress = "127.0.0.1";
    port = 8082;
    dbConnectionString = "socket://${cfg.postgres.user}:*@${cfg.postgres.socketdir}?db=${cfg.postgres.database}";
  };

  services.cardano-node = {
    rtsArgs = lib.mkForce
      (if globals.withHighCapacityExplorer then
        [ "-N2" "-A10m" "-qg" "-qb" "-M10G" ]
      else
        [ "-N2" "-A10m" "-qg" "-qb" "-M3G" ]);
    package = cardano-node;
  };

  systemd.services.cardano-node.serviceConfig.MemoryMax = lib.mkForce
    (if globals.withHighCapacityExplorer then "14G" else "3.5G");

  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    user = "cexplorer";
    extended = globals.withCardanoDBExtended;
    package = if globals.withCardanoDBExtended
      then cardano-db-sync-extended
      else cardano-db-sync;
    postgres = {
      database = "cexplorer";
    };

  };

  systemd.services.cardano-db-sync.serviceConfig = {
    # Put cardano-db-sync in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";
  };

  systemd.services.cardano-rosetta-server.serviceConfig = {
    User = "cexplorer";
    SupplementaryGroups = "cardano-node";
  };

  systemd.services.cardano-graphql = {
    environment = {
      HOME = "/run/${config.systemd.services.cardano-graphql.serviceConfig.RuntimeDirectory}";
    };
    serviceConfig = {
      User = "cexplorer";
      RuntimeDirectory = "cardano-graphql";
      # Put cardano-graphql in "cardano-node" group so that it can write socket file:
      SupplementaryGroups = "cardano-node";
    };
  };

  systemd.services.cardano-submit-api.serviceConfig = lib.mkIf globals.withSubmitApi {
    # Put cardano-db-sync in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
  };

  services.cardano-explorer-api = {
    enable = true;
    port = 8100;
    package = cardano-rest-pkgs.cardanoRestHaskellPackages.cardano-explorer-api.components.exes.cardano-explorer-api;
  };
  systemd.services.cardano-explorer-api.startLimitIntervalSec = 0;
  systemd.services.cardano-explorer-api.serviceConfig.Restart = "always";
  systemd.services.cardano-explorer-api.serviceConfig.RestartSec = "10s";
  systemd.services.cardano-explorer-api.serviceConfig.LimitNOFILE = 4096;

  services.cardano-submit-api = lib.mkIf globals.withSubmitApi {
    enable = true;
    port = 8101;
    environment = pkgs.globals.environmentConfig;
    socketPath = config.services.cardano-node.socketPath;
    package = cardano-rest-pkgs.cardanoRestHaskellPackages.cardano-submit-api.components.exes.cardano-submit-api;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };

  systemd.services.dump-registered-relays-topology = let
    extract_relays_sql = writeText "extract_relays.sql" ''
      select array_to_json(array_agg(row_to_json(t))) from (
        select COALESCE(ipv4, dns_name) as addr, port from (
          select min(update_id) as update_id, ipv4, dns_name, port from pool_relay where
            ipv4 is null or ipv4 !~ '(^0\.)|(^10\.)|(^100\.6[4-9]\.)|(^100\.[7-9]\d\.)|(^100\.1[0-1]\d\.)|(^100\.12[0-7]\.)|(^127\.)|(^169\.254\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.0\.0\.)|(^192\.0\.2\.)|(^192\.88\.99\.)|(^192\.168\.)|(^198\.1[8-9]\.)|(^198\.51\.100\.)|(^203.0\.113\.)|(^22[4-9]\.)|(^23[0-9]\.)|(^24[0-9]\.)|(^25[0-5]\.)'
            group by ipv4, dns_name, port order by update_id
        ) t
      ) t;
    '';
    relays_exclude_file = builtins.toFile "relays-exclude.txt" (lib.concatStringsSep "\n" globals.static.relaysExcludeList);
    networkMagic = (builtins.fromJSON (builtins.readFile globals.environmentConfig.nodeConfig.ShelleyGenesisFile)).networkMagic;
  in {
    path = [ config.services.postgresql.package jq netcat curl dnsutils ];
    script = ''
      set -uo pipefail
      excludeList="$(sort ${relays_exclude_file})"
      cd $STATE_DIRECTORY
      rm -f relays.json
      for r in $(psql -t < ${extract_relays_sql} | jq -c '.[]'); do
        addr=$(echo "$r" | jq -r '.addr')
        port=$(echo "$r" | jq -r '.port')
        allAddresses="$addr\n$(dig +short $addr)"
        excludedAddresses=$(comm -12 <(echo "$allAddresses" | sort) <(echo "$excludeList"))
        nbExcludedAddresses=$(echo $excludedAddresses | wc -w)
        if [[ $nbExcludedAddresses == 0 ]]; then
          set +e
          PING="$(timeout 2s ${cardano-ping}/bin/cardano-ping -h $addr -p $port -m ${toString networkMagic} -c 1 -q --json)"
          res=$?
          if [ $res -eq 0 ]; then
            echo $PING | ${jq}/bin/jq -c > /dev/null 2>&1
            res=$?
          fi
          set -e
          if [ $res -eq 0 ]; then
            >&2 echo "Successfully pinged $addr:$port"
            geoinfo=$(curl -s https://json.geoiplookup.io/$addr)
            continent=$(echo "$geoinfo" | jq -r '.continent_name')
            country_code=$(echo "$geoinfo" | jq -r '.country_code')
            if [ "$country_code" == "US" ]; then
              state=$(echo $geoinfo | jq -r '.region')
            else
              state=$country_code
            fi
            echo $r | jq -c --arg continent "$continent" \
              --arg state "$state" '. + {continent: $continent, state: $state}' >> relays.json
          else
            >&2 echo "failed to cardano-ping $addr:$port"
          fi
        else
          >&2 echo "$addr excluded due to dns name or IPs being in exclude list:\n$excludedAddresses"
        fi
      done
      if [ -f relays.json ]; then
        cat relays.json | jq -n '. + [inputs]' | jq '{ Producers : . }' > topology.json
        mkdir -p relays
        mv topology.json relays/topology.json
      fi
    '';
    serviceConfig = {
      User = cfg.user;
      StateDirectory = "registered-relays-dump";
    };
  };
  systemd.timers.dump-registered-relays-topology = {
    timerConfig.OnCalendar = "hourly";
    wantedBy = [ "timers.target" ];
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
    '';
    virtualHosts = {
      "${globals.explorerHostName}" = {
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
                      <p>Sorry for the inconvenience, but we&rsquo;re performing some maintenance at the moment. We&rsquo;ll be back online shortly!</p>
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
        } else {
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
              rewrite /tx/([0-9a-f]+) /$lang/transaction.html?id=$1 redirect;
              rewrite /address/([0-9a-zA-Z]+) /$lang/address.html?address=$1 redirect;
              rewrite /block/([0-9a-zA-Z]+) /$lang/block.html?id=$1 redirect;
              rewrite /epoch/([0-9]+) /$lang/epoch.html?number=$1 redirect;
              rewrite ^([^.]*[^/])$ $1.html redirect;
            '';
          };
          # To avoid 502 alerts when withSubmitApi is false
          "/api/submit/tx" = lib.mkIf globals.withSubmitApi {
            proxyPass = "http://127.0.0.1:8101/api/submit/tx";
          };
          "/api" = {
            proxyPass = "http://127.0.0.1:8100/api";
            extraConfig = ''
              limit_req zone=apiPerIP;
            '';
          };
          "/graphql" = {
            proxyPass = "http://127.0.0.1:3100/";
          };
          "/rosetta/" = {
            proxyPass = "http://127.0.0.1:8082/";
          };
        }) // {
          "/relays" = {
            root = "/var/lib/registered-relays-dump";
          };
        };
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
}
