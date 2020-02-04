{ config, name, nodes, ... }:
with import ../nix {};

let
  iohkNix = import sourcePaths.iohk-nix {};
  cardano-sl = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  explorerFrontend = cardano-sl.explorerFrontend;
  postgresql12 = (import sourcePaths.nixpkgs-postgresql12 {}).postgresql_12;
  nodeId = config.node.nodeId;
  hostAddr = getListenIp nodes.${name};
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-explorer + "/nix/nixos")
    ../modules/common.nix
  ];

  environment.systemPackages = with pkgs; [ bat fd lsof netcat ncdu ripgrep tree vim cardano-cli ];
  services.postgresql.package = postgresql12;

  services.graphql-engine.enable = false;
  services.cardano-graphql.enable = false;
  services.cardano-node = {
    enable = true;
    extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
    environment = globals.environmentName;
    environments = {
      "${globals.environmentName}" = globals.environmentConfig;
    };
    nodeConfig = globals.environmentConfig.nodeConfig // {
      hasPrometheus = [ hostAddr 12798 ];
      NodeId = nodeId;
    };
  };
  systemd.services.cardano-node.serviceConfig.MemoryMax = "3.5G";
  services.cardano-exporter = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = "/run/cardano-node/node-core-0.socket";
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    #environment = targetEnv;
  };
  systemd.services.cardano-explorer-node = {
    wants = [ "cardano-node.service" ];
    serviceConfig.PermissionsStartOnly = "true";
    preStart = ''
      for x in {1..24}; do
        [ -S "${config.services.cardano-exporter.socketPath}" ] && break
        echo loop $x: waiting for "${config.services.cardano-exporter.socketPath}" 5 sec...
      sleep 5
      done
      chgrp cexplorer "${config.services.cardano-exporter.socketPath}"
      chmod g+w "${config.services.cardano-exporter.socketPath}"
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
