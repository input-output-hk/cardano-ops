{ targetEnv
, nano
, small
, medium               # Standard relay
, xlarge               # Standard explorer
, t3-xlarge            # High load relay
, m5ad-xlarge          # Test node
, xlarge-monitor       # Standard monitor
, t3-2xlarge-monitor   # High capacity monitor
, ...
}:
with (import ../nix {});
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1 concatLists;
  inherit (iohk-ops-lib) roles modules;

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
        roles.monitor
        ../modules/monitoring-cardano.nix
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
          })
        );
      };
    } def;
  }) // (lib.optionalAttrs globals.withExplorer {
    explorer = let def = (topology.explorer or {}); in mkNode {
      deployment.ec2 = {
        region = def.region or "eu-central-1";
        ebsInitialRootDiskSize = 100;
      };
      imports = [
        xlarge
        ../roles/explorer.nix
      ]
      ++ lib.optional (globals.withTxGenerator) ../roles/tx-generator.nix
      # TODO: remove module when the new explorer is available
      ++ lib.optional (globals.withLegacyExplorer) ../roles/explorer-legacy.nix;

      services.monitoring-exporters.extraPrometheusExportersPorts =
        [ globals.cardanoNodePrometheusExporterPort ];

      services.cardano-node.producers = lib.mkIf (coreNodes != [] || relayNodes != [])
        (map (n: n.name) (if relayNodes != [] then relayNodes else coreNodes));

      node = {
        roles.isExplorer = true;
        org = def.org or "IOHK";
        nodeId = def.nodeId or 99;
      };
    } def;
  }) // (lib.optionalAttrs globals.withFaucet {
    "${globals.faucetHostname}" = let def = (topology.faucet or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        medium
        ../roles/faucet.nix
      ];
      node = {
        roles.isFaucet = true;
        org = "IOHK";
      };
    } def;
  });

  nodes = cardanoNodes // otherNodes;

  mkCoreNode =  def: {
    inherit (def) name;
    value = mkNode {
      node = {
        roles.isCardanoCore = true;
        inherit (def) org nodeId;
      };
      deployment.ec2.region = def.region;
      imports = [ medium ../roles/core.nix ];
      services.cardano-node = {
        inherit (def) producers;
      };
    } def;
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        roles.isCardanoRelay = true;
        inherit (def) org nodeId;
      };
      services.cardano-node = {
        inherit (def) producers;
      };
      deployment.ec2.region = def.region;
      imports = if globals.withHighLoadRelays then [
        t3-xlarge ../roles/relay-high-load.nix
      ] else [
        ../roles/relay.nix
        (if (builtins.length def.producers > 1) then small else nano)
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
        ../roles/byron-proxy.nix
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
      imports = [ medium ../roles/legacy-core.nix ];
      # Temporary for legacy migration:
      #imports = [ medium ../roles/legacy-core.nix;
      # ../roles/sync-nonlegacy-chain-state.nix ];
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
      imports = [ medium ../roles/legacy-relay.nix ];
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
      imports = [ m5ad-xlarge ../roles/load-client.nix ];
    } def;
  };

  mkNode = args: def:
    recursiveUpdate (
      recursiveUpdate {
        imports = args.imports ++ (def.imports or []);
        deployment.targetEnv = targetEnv;
        nixpkgs.overlays = pkgs.cardano-ops-overlays;
        _module.args.cardanoNodePkgs = lib.mkDefault cardanoNodePkgs;
      } args)
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
  network.description = "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
