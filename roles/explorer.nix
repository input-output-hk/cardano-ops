{ config, lib, name, nodes, resources, ... }:
with import ../nix {};

let
  nodeCfg = config.services.cardano-node;
  iohkNix = import sourcePaths.iohk-nix {};

  cardano-sl = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  cardano-explorer-app = import sourcePaths.cardano-explorer-app {};
  explorerFrontend = cardano-sl.explorerFrontend;
  postgresql12 = (import sourcePaths.nixpkgs-postgresql12 {}).postgresql_12;
  nodePort = globals.cardanoNodePort;
  nodeId = 99;
  hostAddr = getListenIp nodes.${name};
  hostName = name: "${name}.cardano";
  cardanoNodes = lib.filterAttrs
    (_: node: node.config.services.cardano-node.enable
           or node.config.services.byron-proxy.enable or false)
    nodes;
  cardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = getStaticRouteIp resources nodes nodeName;
  }) cardanoNodes;
    producers = map (n: {
    addr = if (nodes ? ${n}) then hostName n else n;
    port = nodePort;
    valency = 1;
  }) (map (x: x.name) globals.topology.coreNodes);
  topology =  builtins.toFile "topology.yaml" (builtins.toJSON {
    Producers = producers;
  });
  cardanoDbPkgs = import sourcePaths.cardano-db-sync {};
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-graphql + "/nix/nixos")
    (sourcePaths.cardano-rest + "/nix/nixos")
    (sourcePaths.cardano-db-sync + "/nix/nixos")
    ../modules/common.nix
    ../modules/base-service.nix
    ../modules/cardano-postgres.nix
  ];

  networking.extraHosts = ''
    ${lib.concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
  '';

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
    cardanoDbPkgs.haskellPackages.cardano-db.components.exes.cardano-db-tool
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
  services.cardano-graphql.enable = true;
  services.cardano-node = {
    enable = true;
    inherit nodeId;
    extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
    environment = globals.environmentName;
    # extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
    environments = {
      "${globals.environmentName}" = globals.environmentConfig;
    };
    nodeConfig = globals.environmentConfig.nodeConfig // {
      hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
    };
  };

  services.dnsmasq = {
    enable = true;
    servers = [ "127.0.0.1" ];
  };

  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    user = "cexplorer";
    extended = globals.withCardanoDBExtended;
    postgres = {
      database = "cexplorer";
    };
  };
  systemd.services.cardano-explorer-node = {
    wants = [ "cardano-node.service" ];
    serviceConfig.PermissionsStartOnly = "true";
    preStart = ''
      for x in {1..24}; do
        [ -S "${config.services.cardano-db-sync.socketPath}" ] && break
        echo loop $x: waiting for "${config.services.cardano-db-sync.socketPath}" 5 sec...
      sleep 5
      done
      chgrp cexplorer "${config.services.cardano-db-sync.socketPath}"
      chmod g+w "${config.services.cardano-db-sync.socketPath}"
    '';
  };

  services.cardano-explorer-api = {
    enable = true;
  };
  services.cardano-submit-api = {
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    package = nginxExplorer;
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
            root = cardano-explorer-app.static.override {
              graphqlApiHost = "${globals.explorerHostName}.${globals.domain}";
              cardanoNetwork = globals.environmentName;
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
