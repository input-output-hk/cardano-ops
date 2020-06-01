pkgs: { options, config, name, nodes, resources,  ... }:
with pkgs; with lib;
let

  nodeId = config.node.nodeId;
  cfg = config.services.cardano-node;
  nodePort = globals.cardanoNodePort;
  hostAddr = getListenIp nodes.${name};

  monitoringPort = globals.cardanoNodePrometheusExporterPort;

  hostName = name: "${name}.cardano";
  staticRouteIp = getStaticRouteIp resources nodes;

  deployedProducers = lib.filter (n: nodes ? ${n.addr or n}) cfg.producers;

  cardanoHostList = map (nodeName: {
    name = hostName nodeName;
    ip = staticRouteIp nodeName;
  }) deployedProducers;

  producers = map (n: {
    addr = let a = n.addr or n; in if (nodes ? ${a}) then hostName a else a;
    port = n.port or nodePort;
    valency = n.valency or 1;
  }) cfg.producers;

  topology = builtins.toFile "topology.yaml" (builtins.toJSON {
    Producers = producers;
  });
in
{
  imports = [
    cardano-ops.modules.common
    (sourcePaths.cardano-node + "/nix/nixos")
  ];

  options = {
    services.cardano-node = {
      publicIp = mkOption { type = types.str; default = staticRouteIp name;};
      producers = mkOption {
        default = [];
        type = types.listOf (types.either types.str types.attrs);
        description = ''Static routes to peers.'';
      };
    };
  };

  config = {

    environment.systemPackages =
      let completions = pkgs.runCommand "cardano-cli-completions" {} ''
          mkdir -p $out/etc/bash_completion.d
          ${pkgs.cardano-cli}/bin/cardano-cli --bash-completion-script cardano-cli > $out/etc/bash_completion.d/cardano-cli
      '';
      in [ pkgs.cardano-cli completions ];
    environment.variables = {
      CARDANO_NODE_SOCKET_PATH = cfg.socketPath;
    };
    services.monitoring-exporters.extraPrometheusExportersPorts = [ monitoringPort ];

    networking.firewall = {
      allowedTCPPorts = [ nodePort monitoringPort ];

      # TODO: securing this depends on CSLA-27
      # NOTE: this implicitly blocks DHCPCD, which uses port 68
      allowedUDPPortRanges = [ { from = 1024; to = 65000; } ];
    };

    services.cardano-node = {
      enable = true;
      systemdSocketActivation = true;
      rtsArgs = [ "-N2" "-A10m" "-qg" "-qb" "-M3G" ];
      environment = globals.environmentName;
      inherit cardanoNodePkgs hostAddr nodeId topology;
      port = nodePort;
      environments = {
        "${globals.environmentName}" = globals.environmentConfig;
      };
      nodeConfig = globals.environmentConfig.nodeConfig // {
        hasPrometheus = [ hostAddr globals.cardanoNodePrometheusExporterPort ];
        # Use Journald output:
        setupScribes = [{
          scKind = "JournalSK";
          scName = "cardano";
          scFormat = "ScText";
        }];
        defaultScribes = [
          [
            "JournalSK"
            "cardano"
          ]
        ];
      };
    };
    systemd.services.cardano-node = {
      serviceConfig = {
        MemoryMax = "3.5G";
        KillSignal = "SIGINT";
        RestartKillSignal = "SIGINT";
      };
    };

    # FIXME: https://github.com/input-output-hk/cardano-node/issues/1023
    systemd.sockets.cardano-node.partOf = [ "cardano-node.service" ];

    services.dnsmasq = {
      enable = true;
      servers = [ "127.0.0.1" ];
    };

    networking.extraHosts = ''
        ${concatStringsSep "\n" (map (host: "${host.ip} ${host.name}") cardanoHostList)}
    '';
  };
}
