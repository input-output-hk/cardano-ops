{ name, nodes, config, options, ... }:
with (import ../nix {}); with lib;
let
  cfg = config.services.cardano-node-legacy;
  stateDir = "/var/lib/cardano-node";
  publicIP = if options.networking.publicIPv4.isDefined then config.networking.publicIPv4 else null;
  privateIP = if options.networking.privateIPv4.isDefined then config.networking.privateIPv4 else "0.0.0.0";
  nodeToPublicIP   = node:
    let ip = node.config.networking.publicIPv4;
    in if (node.options.networking.publicIPv4.isDefined && ip != null)
    then ip else "";

  command = toString ([
    cfg.executable
    (optionalString (publicIP != null)
     "--address ${publicIP}:${toString cfg.port}")
    "--listen ${privateIP}:${toString cfg.port}"
    (optionalString cfg.jsonLog "--json-log ${stateDir}/jsonLog.json")
    (optionalString (config.services.monitoring-exporters.metrics) "--metrics +RTS -T -RTS --statsd-server 127.0.0.1:${toString config.services.monitoring-exporters.statsdPort}")
    "--keyfile ${stateDir}/key.sk"
    (optionalString (globals.systemStart != 0) "--system-start ${toString globals.systemStart}")
    "--log-config ${cardano-node-legacy-config}/log-configs/cluster.yaml"
    "--logs-prefix /var/lib/cardano-node"
    "--db-path ${stateDir}/node-db"
    "--configuration-file ${cardano-node-legacy-config}/lib/configuration.yaml"
    "--configuration-key ${globals.configurationKey}"
    "--topology ${cfg.topologyYaml}"
    "--node-id ${name}"
  ] ++ cfg.extraCommandArgs);
in {

  imports = [
    iohk-ops-lib.modules.common
  ];

  options = {
    services.cardano-node-legacy = {
      port = mkOption { type = types.int; default = 3000; };
      systemStart = mkOption { type = types.int; default = 0; };

      nodeType = mkOption { type = types.enum [ "core" "relay" "edge" ];};

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

      topologyYaml = mkOption { type = types.path; };

      genesisN = mkOption { type = types.int; default = 6; };
      slotDuration = mkOption { type = types.int; default = 20; };
      networkDiameter = mkOption { type = types.int; default = 15; };
      mpcRelayInterval = mkOption { type = types.int; default = 45; };
      stats = mkOption { type = types.bool; default = false; };
      jsonLog = mkOption { type = types.bool; default = false; };

      staticRoutes = mkOption {
        default = [];
        type = types.listOf types.listOf types.attrs;
        description = ''Static routes to peers.'';
      };

    };
  };

  config = {

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

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];

      # TODO: securing this depends on CSLA-27
      # NOTE: this implicitly blocks DHCPCD, which uses port 68
      allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
    };

    systemd.services.cardano-node-legacy = {
      description   = "cardano node legacy service";
      after         = [ "network.target" "cardano-node-key.service"  ];
      wants = [ "cardano-node-key.service" ];
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
      };
    };

    deployment.keys.cardano-node = {
      user = "cardano-node";
      destDir = "/var/lib/keys";
    };
  };


}
