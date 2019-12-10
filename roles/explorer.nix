{ config, ... }:
with import ../nix {};

let
  cardano-sl = import sourcePaths.cardano-sl { gitrev = sourcePaths.cardano-sl.rev; };
  explorerFrontend = cardano-sl.explorerFrontend;
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-explorer + "/nix/nixos")
    ../modules/common.nix
  ];

  environment.systemPackages = with pkgs; [ bat fd lsof netcat ncdu ripgrep tree vim cardano-cli ];

  services.graphql-engine.enable = false;
  services.cardano-graphql.enable = false;
  services.cardano-node = {
    extraArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-h" "-M3G" "-RTS" ];
    environment = globals.environmentName;
    environments = {
      "${globals.environmentName}" = globals.environmentConfig;
    };
    # Remove when update to next release:
    genesisHash = globals.environmentConfig.genesisHash;
    enable = true;
  };
  services.cardano-exporter = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = "/run/cardano-node/node-core-0.socket";
    #environment = targetEnv;
  };
  systemd.services.cardano-explorer-node = {
    wants = [ "cardano-node.service" ];
    serviceConfig.PermissionsStartOnly = "true";
    preStart = ''
      for x in {1..24}; do
        [ -S ${config.services.cardano-exporter.socketPath} ] && break
        echo loop $x: waiting for ${config.services.cardano-exporter.socketPath} 5 sec...
      sleep 5
      done
      chgrp cexplorer ${config.services.cardano-exporter.socketPath}
      chmod g+w ${config.services.cardano-exporter.socketPath}
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
        #locations."/graphql" = {
        #  proxyPass = "http://127.0.0.1:3100/graphql";
        #};
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
