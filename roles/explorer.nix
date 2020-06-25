pkgs: { config, options, name, nodes, ... }:
with pkgs;

let
  nodeCfg = config.services.cardano-node;
  nodeId = config.node.nodeId;
  hostAddr = getListenIp nodes.${name};
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-graphql + "/nix/nixos")
    (sourcePaths.cardano-rest + "/nix/nixos")
    (sourcePaths.cardano-db-sync + "/nix/nixos")
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
    cardano-db-sync-pkgs.haskellPackages.cardano-db.components.exes.cardano-db-tool
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
    whitelistPath = cardano-explorer-app-pkgs.whitelist;
  };
  services.cardano-node.rtsArgs = lib.mkForce
    (if globals.withHighCapacityExplorer then
      [ "-N2" "-A10m" "-qg" "-qb" "-M10G" ]
    else
      [ "-N2" "-A10m" "-qg" "-qb" "-M3G" ]);

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
      then cardano-db-sync-pkgs.cardano-db-sync-extended
      else cardano-db-sync-pkgs.cardano-db-sync;
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

  services.cardano-explorer-api = {
    enable = true;
    package = cardano-rest-pkgs.cardanoRestHaskellPackages.cardano-explorer-api.components.exes.cardano-explorer-api;
  };
  systemd.services.cardano-explorer-api.startLimitIntervalSec = 0;
  systemd.services.cardano-explorer-api.serviceConfig.Restart = "always";
  systemd.services.cardano-explorer-api.serviceConfig.RestartSec = "10s";

  services.cardano-submit-api = {
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
        select ipv4, dns_name, port from (
          select min(pool_id) as pool_id, ipv4, dns_name, port from pool_relay where
            ipv4 is null or ipv4 !~ '(^0\.)|(^10\.)|(^100\.6[4-9]\.)|(^100\.[7-9]\d\.)|(^100\.1[0-1]\d\.)|(^100\.12[0-7]\.)|(^127\.)|(^169\.254\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.0\.0\.)|(^192\.0\.2\.)|(^192\.88\.99\.)|(^192\.168\.)|(^198\.1[8-9]\.)|(^198\.51\.100\.)|(^203.0\.113\.)|(^22[4-9]\.)|(^23[0-9]\.)|(^24[0-9]\.)|(^25[0-5]\.)'
            group by ipv4, dns_name, port order by pool_id
        ) t
      ) t;
    '';
  in {
    path = [ config.services.postgresql.package jq dnsutils ];
    script = ''
      cd $STATE_DIRECTORY
      for r in $(psql -t < ${extract_relays_sql} | jq -c '.[]'); do
      dns_name=$(echo $r | jq -r '.dns_name')
      if [ "$dns_name" != "null" ]; then
        nslookup $dns_name > /dev/null
        if [ "$?" -eq "0" ]; then
          echo $r | jq '{"addr": .dns_name} + . | del(.ipv4) | del(.dns_name)'
        fi
      else
        echo $r | jq '{"addr": .ipv4} + . | del(.ipv4) | del(.dns_name)'
      fi
      done | jq -n '. + [inputs]' | jq '{ Producers : . }' > topology.json
      mkdir -p relays
      mv topology.json relays/topology.json
    '';
    serviceConfig = {
      User = config.services.cardano-db-sync.user;
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
      map $http_accept_language $lang {
              default en;
              ~de de;
              ~ja ja;
      }
    '';
    virtualHosts = {
      "${globals.explorerHostName}.${globals.domain}" = {
        serverAliases = globals.explorerAliases;
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations = {
          "/" = {
            root = cardano-explorer-app-pkgs.static.override {
              graphqlApiHost = "${globals.explorerHostName}.${globals.domain}";
              cardanoNetwork = globals.environmentName;
              gaTrackingId = globals.static.gaTrackingId or null;
            };
            tryFiles = "$uri $uri/index.html /index.html";
            extraConfig = ''
              rewrite /tx/([0-9a-f]+) /$lang/transaction?id=$1 redirect;
              rewrite /address/([123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+) /$lang/address?address=$1 redirect;
            '';
          };
          "/api" = {
            proxyPass = "http://127.0.0.1:8100/api";
          };
          "/graphql" = {
            proxyPass = "http://127.0.0.1:3100/graphql";
          };
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
