{ pkgs, name, nodes, config, options, resources, ... }:
with (import ../nix {}); with lib;
let
  inherit (iohkNix.cardanoLib) cardanoConfig;
  cfg = config.services.cardano-node-legacy;
  stateDir = "/var/lib/cardano-node";
  port = globals.cardanoNodeLegacyPort;
  command = toString ([
    cfg.executable
    "--address ${cfg.publicIp}:${toString port}"
    "--listen ${cfg.listenIp}:${toString port}"
    (optionalString cfg.jsonLog "--json-log ${stateDir}/jsonLog.json")
    (optionalString (config.services.monitoring-exporters.metrics) "--metrics +RTS -T -RTS --statsd-server 127.0.0.1:${toString config.services.monitoring-exporters.statsdPort}")
    (optionalString (cfg.nodeType == "core") "--keyfile ${stateDir}/key.sk")
    "--log-config ${cardano-node-legacy-config}/log-configs/cluster.yaml"
    "--logs-prefix /var/lib/cardano-node"
    "--db-path ${stateDir}/node-db"
    "--configuration-file ${cardanoConfig}/configuration.yaml"
    "--configuration-key ${globals.environmentConfig.confKey}"
    "--topology ${cfg.topologyYaml}"
    "--node-id ${name}"
  ] ++ cfg.extraCommandArgs);
in {

  imports = [
    ./common-cardano-legacy.nix
  ];

  options = {
    services.cardano-node-legacy = {
      enable = mkEnableOption "cardano-node-legacy"  // { default = true; };

      extraCommandArgs = mkOption { type = types.listOf types.str; default = []; };
      saveCoreDumps = mkOption {
        type = types.bool;
        default = true;
        description = "automatically save coredumps when cardano-node segfaults";
      };

      executable = mkOption {
        type = types.str;
        description = "Executable to run as the daemon.";
        default = "${cardano-node-legacy}/bin/cardano-node-simple";
      };
      autoStart = mkOption { type = types.bool; default = true; };
      jsonLog = mkOption { type = types.bool; default = false; };
    };
  };

  config = mkIf cfg.enable {

    users = {
      users.cardano-node = {
        uid             = 10014;
        description     = "cardano-node server user";
        group           = "cardano-node";
        home            = stateDir;
        createHome      = true;
        extraGroups     = [ "keys" ];
      };
      groups.cardano-node = {
        gid = 123123;
      };
    };

    systemd.services.cardano-node-legacy = {
      description   = "cardano node legacy service";
      after         = [ "network.target" ];
      wantedBy = optionals cfg.autoStart [ "multi-user.target" ];
      script = ''
        [ -f /var/lib/keys/cardano-node ] && cp -f /var/lib/keys/cardano-node ${stateDir}/key.sk
        ${optionalString (cfg.saveCoreDumps) ''
          # only a process with non-zero coresize can coredump (the default is 0)
          ulimit -c unlimited
        ''}
        exec ${command}
      '';
      serviceConfig = {
        User = "cardano-node";
        Group = "cardano-node";
        # Allow a maximum of 5 retries separated by 30 seconds, in total capped by 200s
        Restart = "always";
        RestartSec = 30;
        StartLimitInterval = 200;
        StartLimitBurst = 5;
        KillSignal = "SIGINT";
        WorkingDirectory = stateDir;
        PrivateTmp = true;
        Type = "notify";
        MemoryMax = "3.5G";
      };
    };
  };
}
