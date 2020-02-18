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
  socketPath = nodeCfg.socketPath or "/run/cardano-node/node-${toString nodeId}.socket";
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-explorer + "/nix/nixos/cardano-exporter-service.nix")
    (sourcePaths.cardano-explorer + "/nix/nixos/cardano-tx-submitter.nix")
    (sourcePaths.cardano-explorer + "/nix/nixos/cardano-explorer-webapi.nix")
    (sourcePaths.cardano-explorer + "/nix/nixos/cardano-explorer-everything.nix")
    (sourcePaths.cardano-graphql + "/nix/nixos")
    ../modules/common.nix
  ];

  environment.systemPackages = with pkgs; [ bat fd lsof netcat ncdu ripgrep tree vim cardano-cli ];
  services.postgresql.package = postgresql12;

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
  # TODO remove next two line for next release cardano-node 1.7 release:
  systemd.services.cardano-node.scriptArgs = toString nodeId;
  systemd.services.cardano-node.preStart = ''
    if [ -d ${nodeCfg.databasePath}-0 ]; then
      mv ${nodeCfg.databasePath}-0 ${nodeCfg.databasePath}
    fi
  '';
  services.cardano-exporter = {
    enable = true;
    inherit socketPath;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    #environment = targetEnv;
  };
  systemd.services.cardano-explorer-node = {
    wants = [ "cardano-node.service" ];
    serviceConfig.PermissionsStartOnly = "true";
    preStart = ''
      for x in {1..24}; do
        [ -S "${socketPath}" ] && break
        echo loop $x: waiting for "${socketPath}" 5 sec...
      sleep 5
      done
      chgrp cexplorer "${socketPath}"
      chmod g+w "${socketPath}"
    '';
  };

  services.cardano-explorer-webapi.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "explorer.${globals.domain}" = {
        enableACME = true;
        forceSSL = true;
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
