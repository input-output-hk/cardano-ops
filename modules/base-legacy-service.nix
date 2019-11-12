{ pkgs, name, nodes, config, options, resources, ... }:
with (import ../nix {}); with lib;
let
  iohkNix = import sourcePaths.iohk-nix {};
  inherit (iohkNix) cardanoLib;
  inherit (iohkNix.cardanoLib) cardanoConfig;
  cfg = config.services.cardano-node-legacy;
  stateDir = "/var/lib/cardano-node";
  listenIp =
    let ip = config.networking.privateIPv4;
    in if (options.networking.privateIPv4.isDefined && ip != null) then ip else "0.0.0.0";
  publicIp = staticRouteIp name;

  hostName = name: "${name}.cardano";
  cardanoNodes = filterAttrs
    (_: node: node.config.services.cardano-node-legacy.enable or false)
    nodes;
  cardanoHostList = lib.mapAttrsToList (nodeName: node: {
    name = hostName nodeName;
    ip = resources.elasticIPs."${nodeName}-ip".address;
  }) cardanoNodes;

  topology = {
    nodes = mapAttrs (name: node: let nodeCfg = node.config.services.cardano-node-legacy; in {
      type = nodeCfg.nodeType;
      region = node.config.deployment.ec2.region;
      host = hostName name;
      port = nodeCfg.port;
    } // optionalAttrs (concatLists nodeCfg.staticRoutes != []) {
      static-routes = nodeCfg.staticRoutes;
    } // optionalAttrs (concatLists nodeCfg.dynamicSubscribe != []) {
      dynamic-subscribe = map (map (h: {
        "host" = if (nodes ? h) then hostName h else h;
      })) nodeCfg.dynamicSubscribe;
    }) cardanoNodes;
  };

  nodeName = node: head (attrNames (filterAttrs (_: n: n == node) nodes));

  staticRouteIp = nodeName: resources.elasticIPs."${nodeName}-ip".address
    or (let
      publicIp = nodes.${nodeName}.config.networking.publicIPv4;
      privateIp = nodes.${nodeName}.config.networking.privateIPv4;
    in
      if (nodes.${nodeName}.options.networking.publicIPv4.isDefined && publicIp != null) then publicIp
      else if (nodes.${nodeName}.options.networking.privateIPv4.isDefined && privateIp != null) then privateIp
      else abort "No suitable ip found for node: ${nodeName}"
    );

  peersHostList = concatMap (map (nodeName: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  })) (cfg.staticRoutes ++ map (filter (h: nodes ? h)) cfg.dynamicSubscribe);

  command = toString ([
    cfg.executable
    "--address ${publicIp}:${toString cfg.port}"
    "--listen ${listenIp}:${toString cfg.port}"
    (optionalString cfg.jsonLog "--json-log ${stateDir}/jsonLog.json")
    (optionalString (config.services.monitoring-exporters.metrics) "--metrics +RTS -T -RTS --statsd-server 127.0.0.1:${toString config.services.monitoring-exporters.statsdPort}")
    (optionalString (cfg.nodeType == "core") "--keyfile ${stateDir}/key.sk")
    (optionalString (globals.systemStart != 0) "--system-start ${toString globals.systemStart}")
    "--log-config ${cardano-node-legacy-config}/log-configs/cluster.yaml"
    "--logs-prefix /var/lib/cardano-node"
    "--db-path ${stateDir}/node-db"
    "--configuration-file ${cardanoConfig}/configuration.yaml"
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
      enable = mkEnableOption "cardano-node-legacy"  // { default = true; };
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

      topologyYaml = mkOption {
        type = types.path;
        default = writeText "topology.yaml"  (builtins.toJSON topology);
      };

      genesisN = mkOption { type = types.int; default = 6; };
      slotDuration = mkOption { type = types.int; default = 20; };
      networkDiameter = mkOption { type = types.int; default = 15; };
      mpcRelayInterval = mkOption { type = types.int; default = 45; };
      stats = mkOption { type = types.bool; default = false; };
      jsonLog = mkOption { type = types.bool; default = false; };

      staticRoutes = mkOption {
        default = [];
        type = types.listOf (types.listOf types.str);
        description = ''Static routes to peers.'';
      };

      dynamicSubscribe = mkOption {
        default = [];
        type = types.listOf (types.listOf types.str);
        description = ''Dnymic subscribe routes.'';
      };

    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.telnet ];

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
      };
    };

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
      ${publicIp} ${hostName name}
      ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };


}
