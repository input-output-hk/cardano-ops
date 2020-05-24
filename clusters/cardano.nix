{ pkgs
, targetEnv
, nano
, small
, medium               # Standard relay
, xlarge               # Standard explorer
, t3-xlarge            # High load relay
, m5ad-xlarge          # Test node
, xlarge-monitor       # Standard monitor
, t3-2xlarge-monitor   # High capacity monitor, explorer
, ...
}:
with pkgs;
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1 concatLists;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done

  cardanoNodes = listToAttrs (concatLists [
    (map mkLegacyCoreNode legacyCoreNodes)
    (map mkLegacyRelayNode legacyRelayNodes)
    (map mkCoreNode coreNodes)
    (map mkRelayNode relayNodes)
    (map mkByronProxyNode byronProxies)
    (map mkTestNode (topology.testNodes or []))
  ]);

  otherNodes = (lib.optionalAttrs globals.withMonitoring {
    monitoring = let def = (topology.monitoring or {}); in mkNode {
      deployment.ec2.region = def.region or "eu-central-1";
      imports = [
        (if globals.withHighCapacityMonitoring then t3-2xlarge-monitor else xlarge-monitor)
        iohk-ops-lib.roles.monitor
        (cardano-ops.modules.monitoring-cardano pkgs)
      ];
      node = {
        roles.isMonitor = true;
        org = def.org or "IOHK";
      };

      services.prometheus = {
        scrapeConfigs = (lib.optionals globals.withExplorer ([
          # TODO: remove once explorer exports metrics at path `/metrics`
          {
            job_name = "explorer-exporter";
            scrape_interval = "10s";
            metrics_path = "/metrics2/exporter";
            static_configs = [{
              targets = [ "explorer-ip" ];
              labels = { alias = "explorer-exporter"; };
            }];
          }
          {
            job_name = "cardano-graphql-exporter";
            scrape_interval = "10s";
            metrics_path = "/metrics2/cardano-graphql";
            static_configs = [{
              targets = [ "explorer-ip" ];
              labels = { alias = "cardano-graphql-exporter"; };
            }];
          }
          ])) ++ (lib.optional globals.withLegacyExplorer (
          # TODO: remove once explorer python api is deprecated
          {
            job_name = "explorer-python-api";
            scrape_interval = "10s";
            metrics_path = "/metrics/explorer-python-api";
            static_configs = [{
              targets = [ "explorer-ip" ];
              labels = { alias = "explorer-python-api"; };
            }];
          })) ++ (lib.optional globals.withFaucet (
          {
            job_name = "cardano-faucet";
            scrape_interval = "10s";
            metrics_path = "/metrics";
            static_configs = [{
              targets = [ "${globals.faucetHostname}.${globals.domain}" ];
              labels = { alias = "cardano-faucet"; };
            }];
          }));
          #})) ++
          #[{
          #  job_name = "netdata";
          #  scrape_interval = "60s";
          #  metrics_path = "/api/v1/allmetrics?format=prometheus";
          #  static_configs = pkgs.lib.traceValFn (x: __toJSON x) (map (n: {
          #    targets = [ "${n.name}-ip:${toString globals.netdataExporterPort}" ];
          #    labels = { alias = "${n.name}"; };
          #  }) (coreNodes ++ relayNodes ++ (topology.testNodes or [])));
          #}];
      };
    } def;
  }) // (lib.optionalAttrs globals.withExplorer {
    explorer = let def = (topology.explorer or {}); in mkNode {
      _file = ./cardano.nix;
      deployment.ec2 = {
        region = def.region or "eu-central-1";
        ebsInitialRootDiskSize = if globals.withHighCapacityExplorer then 1000 else 100;
      };
      imports = [
        (if globals.withHighCapacityExplorer then t3-2xlarge-monitor else xlarge)
        cardano-ops.roles.explorer
      ]
      # TODO: remove module when the new explorer is available
      ++ lib.optional (globals.withLegacyExplorer) cardano-ops.roles.explorer-legacy;

      services.monitoring-exporters.extraPrometheusExportersPorts =
        [ globals.cardanoNodePrometheusExporterPort ];

      services.cardano-node.producers = if (relayNodes != [])
        then [ pkgs.globals.relaysNew ]
        else (map (n: n.name) coreNodes);

      node = {
        roles.isExplorer = true;
        org = def.org or "IOHK";
        nodeId = def.nodeId or 99;
      };
    } def;
  }) // (lib.optionalAttrs globals.withFaucet {
    "${globals.faucetHostname}" = let def = (topology.${globals.faucetHostname} or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        medium
        cardano-ops.roles.faucet
      ];
      node = {
        roles.isFaucet = true;
        org = "IOHK";
      };
    } def;
  })// (lib.optionalAttrs globals.withSmash {
    smash = let def = (topology.smash or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        xlarge
        cardano-ops.roles.smash
      ];
      node = {
        roles.isExplorer = true;
        nodeId = def.nodeId or 100;
        org = "IOHK";
      };
    } def;
  });

  nodes = cardanoNodes // otherNodes;

  mkCoreNode =  def: {
    inherit (def) name;
    value = mkNode {
      _file = ./cardano.nix;
      node = {
        roles.isCardanoCore = true;
        inherit (def) org nodeId;
      };
      deployment.ec2.region = def.region;
      imports = [
        medium
        (cardano-ops.roles.core def.nodeId)
      ];
      services.cardano-node = {
        inherit (def) producers;
      };
    } def;
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = mkNode {
      _file = ./cardano.nix;
      node = {
        roles.isCardanoRelay = true;
        inherit (def) org nodeId;
      };
      services.cardano-node = {
        inherit (def) producers;
      };
      deployment.ec2.region = def.region;
      imports = if (def.withHighLoadRelays or globals.withHighLoadRelays) then [
        t3-xlarge cardano-ops.roles.relay-high-load
      ] else [
        medium cardano-ops.roles.relay
      ];
    } def;
  };

  mkByronProxyNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        roles.isByronProxy = true;
        inherit (def) org nodeId;
      };
      services.byron-proxy = {
        inherit (def) producers;
      };
      deployment.ec2.region = def.region;
      imports = [
        medium
        cardano-ops.roles.byron-proxy
      ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];

      services.monitoring-exporters.extraPrometheusExportersPorts = [ globals.byronProxyPrometheusExporterPort ];

    } def;
  };

  mkLegacyCoreNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        roles.isCardanoLegacyCore = true;
        inherit (def) org nodeId;
      };
      deployment.ec2.region = def.region;
      imports = [ medium cardano-ops.roles.legacy-core ];
      # Temporary for legacy migration:
      #imports = [ medium cardano-ops.roles.legacy-core
      # cardano-ops.roles.sync-nonlegacy-chain-state ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    } def;
  };

  mkLegacyRelayNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        roles.isCardanoLegacyRelay = true;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ medium cardano-ops.roles.legacy-relay ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];
    } def;
  };

  # Load client with optimized NVME disks, for prometheus monitored clients syncs
  mkTestNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ m5ad-xlarge cardano-ops.roles.load-client ];
    } def;
  };

  mkNode = args: def:
    recursiveUpdate (
      recursiveUpdate {
        deployment.targetEnv = targetEnv;
        nixpkgs.pkgs = pkgs;
      } (args // {
        imports = args.imports ++ (def.imports or []);
      }))
      (builtins.removeAttrs def [
        "imports"
        "name"
        "org"
        "region"
        "nodeId"
        "producers"
        "staticRoutes"
        "dynamicSubscribe"
      ]);

in {
  network.description =
    globals.networkName
      or
    "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
