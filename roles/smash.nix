pkgs: with pkgs; { nodes, name, config, ... }:
let
  nodeCfg = config.services.cardano-node;
  cfg = config.services.smash;
  hostAddr = getListenIp nodes.${name};
in {
  environment = {
    systemPackages = [
      bat fd lsof netcat ncdu ripgrep tree vim cardano-cli
    ];
    variables = {
      SMASHPGPASSFILE = cfg.postgres.pgpass;
    };
  };
  imports = [
    cardano-ops.modules.base-service
    cardano-ops.modules.cardano-postgres
    (sourcePaths.smash+ "/nix/nixos")
  ];
  services.cardano-node.producers = [ globals.relaysNew ];
  systemd.services.smash.serviceConfig = {
    # Put cardano-db-sync in "cardano-node" group so that it can write socket file:
    SupplementaryGroups = "cardano-node";
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";
  };
  services.smash = {
    enable = true;
    inherit (globals) environmentName;
    environment = globals.environmentConfig;
    inherit (nodeCfg) socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { hasPrometheus = [ hostAddr 12698 ]; };
  };
  services.cardano-postgres.enable = true;
  services.postgresql = {
    ensureDatabases = [ "${cfg.postgres.database}" ];
    ensureUsers = [
      {
        name = "${cfg.postgres.user}";
        ensurePermissions = {
          "DATABASE ${cfg.postgres.database}" = "ALL PRIVILEGES";
        };
      }
    ];
    identMap = ''
      smash-users root ${cfg.postgres.user}
      smash-users ${cfg.user} ${cfg.postgres.user}
      smash-users postgres postgres
    '';
    authentication = ''
      local all all ident map=smash-users
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
    commonHttpConfig =
      let apiKeys = import ../static/smash-keys.nix;
      in ''
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" "$http_accept_language" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

      access_log syslog:server=unix:/dev/log x-fwd;
      map $arg_apiKey $api_client_name {
        default "";

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (client: key: "\"${key}\" \"${client}\";") apiKeys)}
      }
    '';
    virtualHosts = {
      "smash.${globals.domain}" = {
        enableACME = true;
        forceSSL = globals.explorerForceSSL;
        locations =
          let apiKeyConfig = ''
            if ($arg_apiKey = "") {
                return 401; # Unauthorized (please authenticate)
            }
            if ($api_client_name = "") {
                return 403; # Forbidden (invalid API key)
            }
          '';
          in lib.recursiveUpdate (lib.genAttrs ["/swagger.json" "/api/v1/metadata" "/api/v1/errors" "/api/v1/delist"] (p: {
            proxyPass = "http://127.0.0.1:3100${p}";
          })) {
            "/api/v1/errors".extraConfig = ''
              if ($arg_poolId) {
                set $arg_apiKey NONE;
                set $api_client_name BYPASS;
              }
              ${apiKeyConfig}
            '';
            "/api/v1/delist".extraConfig = apiKeyConfig;
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
