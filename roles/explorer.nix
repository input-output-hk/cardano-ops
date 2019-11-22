{ config, ... }:
with import ../nix {};

let
  inherit (import sourcePaths.iohk-nix {}) cardanoLib;
  cluster = globals.environment;
  targetEnv = cardanoLib.environments.${cluster};
in {
  imports = [
    (sourcePaths.cardano-node + "/nix/nixos")
    (sourcePaths.cardano-explorer + "/nix/nixos")
    ../modules/common.nix
  ];

  environment.systemPackages = with pkgs; [ bat fd lsof netcat ncdu ripgrep tree vim ];

  services.graphql-engine.enable = true;
  services.cardano-graphql.enable = true;
  services.cardano-node = {
    inherit (globals) environment;
    environments = cardanoLib.environments;
    enable = true;
  };
  services.cardano-exporter = {
    enable = true;
    cluster = globals.environment;
    socketPath = "/run/cardano-node/node-core-0.socket";
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

  services.cardano-explorer-api.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    virtualHosts."explorer.${globals.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:3100/";
    };
  };
}
