pkgs: {
  dbSyncPkgs,
  cardanoNodePkgs,
  additionalDbUsers ? []
} : { name, config, options, ... }:
with pkgs;

let
  cfg = config.services.cardano-db-sync;
  nodeCfg = config.services.cardano-node;

  cardanoNodeConfigPath = builtins.toFile "cardano-node-config.json" (builtins.toJSON nodeCfg.nodeConfig);

  inherit (dbSyncPkgs) cardanoDbSyncHaskellPackages;
  package = cardanoDbSyncHaskellPackages.cardano-db-sync-extended.components.exes.cardano-db-sync-extended
    # No more extended from 13.x onward:
    or cardanoDbSyncHaskellPackages.cardano-db-sync.components.exes.cardano-db-sync;
  inherit (cardanoDbSyncHaskellPackages.cardano-db-tool.components.exes) cardano-db-tool;
in {

  imports = [
    cardano-ops.modules.cardano-postgres
    cardano-ops.modules.base-service
    (sourcePaths.cardano-db-sync-service + "/nix/nixos")
  ];

  environment.systemPackages = with pkgs; [
    bat fd lsof netcat ncdu ripgrep tree vim dnsutils
    cardano-db-tool
  ];

  services.cardano-postgres.enable = true;
  services.postgresql = {
    ensureDatabases = [ "cexplorer" "cgql" ];
    initialScript = builtins.toFile "enable-pgcrypto.sql" ''
      \connect template1
      CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA pg_catalog;
    '';
    ensureUsers = [
      {
        name = "cexplorer";
        ensurePermissions = {
          "DATABASE cexplorer" = "ALL PRIVILEGES";
          "DATABASE cgql" = "ALL PRIVILEGES";
          "ALL TABLES IN SCHEMA information_schema" = "SELECT";
          "ALL TABLES IN SCHEMA pg_catalog" = "SELECT";
        };
      }
    ];
    identMap = ''
      explorer-users postgres postgres
    ${lib.concatMapStrings (user: ''
      explorer-users ${user} cexplorer
    '') (["root" "cardano-db-sync" ] ++ additionalDbUsers)}'';
    authentication = ''
      local all all ident map=explorer-users
    '';
  };

  services.cardano-node = {
    inherit cardanoNodePkgs;
    allProducers = if (globals.topology.relayNodes != [] || (globals.deploymentName != globals.environmentName))
        then [ (topology-lib.envRegionalRelaysProducer config.deployment.ec2.region 2) ]
        else if (globals.topology.coreNodes != [])
        then (map (n: n.name) globals.topology.coreNodes)
        else [ (topology-lib.envRegionalRelaysProducer config.deployment.ec2.region 2) ];
    totalMaxHeapSizeMbytes = 0.25 * config.node.memory * 1024;
  };

  services.cardano-db-sync = {
    enable = true;
    inherit package;
    cluster = globals.environmentName;
    environment = globals.environmentConfig;
    inherit (cfg.environment) explorerConfig;
    socketPath = nodeCfg.socketPath;
    logConfig = iohkNix.cardanoLib.defaultExplorerLogConfig // { PrometheusPort = globals.cardanoExplorerPrometheusExporterPort; };
    inherit dbSyncPkgs;
    postgres = {
      database = "cexplorer";
    };
  };

  systemd.services.cardano-db-sync.serviceConfig = {
    # FIXME: https://github.com/input-output-hk/cardano-db-sync/issues/102
    Restart = "always";
    RestartSec = "30s";
  };

  services.monitoring-exporters.extraPrometheusExporters = [
    # TODO: remove once explorer exports metrics at path `/metrics`
    {
      job_name = "explorer-exporter";
      scrape_interval = "10s";
      port = globals.cardanoExplorerPrometheusExporterPort;
      metrics_path = "/";
      labels = { alias = "${name}-exporter"; };
    }
  ];
}
