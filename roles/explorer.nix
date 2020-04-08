{ config, name, nodes, ... }:
with import ../nix {};

let
  nodeCfg = config.services.cardano-node;
  iohkNix = import sourcePaths.iohk-nix {};
  cardano-sl = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  explorerFrontend = cardano-sl.explorerFrontend;
  postgresql12 = (import sourcePaths.nixpkgs-postgresql12 {}).postgresql_12;
  nodeId = config.node.nodeId;
  hostAddr = getListenIp nodes.${name};
  cardanoDbPkgs = import sourcePaths.cardano-db-sync {};
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-graphql + "/nix/nixos")
    (sourcePaths.cardano-rest + "/nix/nixos")
    (sourcePaths.cardano-db-sync + "/nix/nixos")
    ../modules/common.nix
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
    cardanoDbPkgs.haskellPackages.cardano-db.components.exes.cardano-db-tool
  ];
  services.postgresql = {
    package = postgresql12;
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
    environments = {
      "${globals.environmentName}" = globals.environmentConfig;
    };

    nodeConfig = globals.environmentConfig.nodeConfig // {
      hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
    };
  };
  systemd.services.cardano-node.serviceConfig.MemoryMax = "3.5G";
  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    user = "cexplorer";
    extended = true;
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

  services.cardano-explorer-api.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "${globals.explorerHostName}.${globals.domain}" = {
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations = {
          "/" = {
            root = explorerFrontend;
          };
          #"/socket.io/" = {
          #   proxyPass = "http://127.0.0.1:8110";
          #   extraConfig = ''
          #     proxy_http_version 1.1;
          #     proxy_set_header Upgrade $http_upgrade;
          #     proxy_set_header Connection "upgrade";
          #     proxy_read_timeout 86400;
          #   '';
          #};
          "/api" = {
            proxyPass = "http://127.0.0.1:8100/api";
          };
        };
        #locations."/graphiql" = {
        #  proxyPass = "http://127.0.0.1:3100/graphiql";
        #};
        locations."/graphql" = {
          proxyPass = "http://127.0.0.1:3100/graphql";
        };
      };
      "explorer-ip" = {
        locations = {
          "/metrics2/exporter" = {
            proxyPass = "http://127.0.0.1:8080/";
          };
        };
      };
    };
  };
}
