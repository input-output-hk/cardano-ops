pkgs: with pkgs; { nodes, name, config, ... }:
let
  nodeCfg = config.services.cardano-node;
  dbSyncCfg = config.services.cardano-db-sync;
  hostAddr = getListenIp nodes.${name};
in {
  environment = {
    systemPackages = [
      bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
      cardano-db-sync-pkgs.haskellPackages.cardano-db.components.exes.cardano-db-tool
    ];
    variables = {
      PGPASSFILE = config.services.cardano-db-sync.pgpass;
    };
  };
  imports = [
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
    (sourcePaths.cardano-db-sync + "/nix/nixos")
    (sourcePaths.smash+ "/nix/nixos")
  ];
  services.cardano-node.producers = [ globals.relaysNew ];
  services.cardano-db-sync = {
    enable = true;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
    extended = globals.withCardanoDBExtended;
    package = if globals.withCardanoDBExtended
      then cardano-db-sync-pkgs.cardano-db-sync-extended
      else cardano-db-sync-pkgs.cardano-db-sync;
  };
  services.smash.enable = true;
  services.cardano-postgres.enable = true;
  services.postgresql = {
    ensureDatabases = [ "${dbSyncCfg.user}" ];
    ensureUsers = [
      {
        name = "${dbSyncCfg.user}";
        ensurePermissions = {
          "DATABASE ${dbSyncCfg.user}" = "ALL PRIVILEGES";
        };
      }
    ];
    identMap = ''
      cdbsync-users root ${dbSyncCfg.user}
      cdbsync-users smash ${dbSyncCfg.user}
      cdbsync-users ${dbSyncCfg.user} ${dbSyncCfg.user}
      cdbsync-users postgres postgres
    '';
    authentication = ''
      local all all ident map=cdbsync-users
    '';
  };
  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" "$http_accept_language" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd;
    '';
    virtualHosts = {
      "smash.${globals.domain}" = {
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations = {
          "/api" = {
            proxyPass = "http://127.0.0.1:3100/api";
          };
        };
      };
      "smash-ip" = {
        locations = {
          "/metrics2/exporter" = {
            proxyPass = "http://127.0.0.1:8080/";
          };
        };
      };
    };
  };
}
