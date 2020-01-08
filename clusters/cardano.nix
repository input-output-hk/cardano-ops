{ targetEnv
, medium
, xlarge
, xlarge-monitor
, ...
}:
with (import ../nix {});
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) legacyCoreNodes legacyRelayNodes byronProxies coreNodes relayNodes;
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1;
  inherit (iohk-ops-lib) roles modules;

  # for now, keys need to be generated for each core nodes with:
  # for i in {1..2}; do cardano-cli --byron-legacy keygen --secret ./keys/$i.sk --no-password; done

  cardanoNodes = listToAttrs (imap1 mkLegacyCoreNode legacyCoreNodes)
    // listToAttrs (map mkLegacyRelayNode legacyRelayNodes)
    // listToAttrs (map mkCoreNode coreNodes)

    # Relays will be defined explicitly for now since they may need several overrides
    # for different environments, patches, etc
    #// listToAttrs (map mkRelayNode relayNodes)

    // listToAttrs (map mkByronProxyNode byronProxies);

  otherNodes = (lib.optionalAttrs globals.withMonitoring {
    monitoring = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        xlarge-monitor
        roles.monitor
        ../modules/monitoring-cardano.nix
      ];
      node = {
        roles.isMonitor = true;
        org = "IOHK";
      };
      services.monitoring-services.logging = false;
      services.graylog.enable = false;
      services.prometheus = lib.mkIf globals.withExplorer {
        scrapeConfigs = [
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
          # TODO: remove once explorer python api is deprecated
          {
            job_name = "explorer-python-api";
            scrape_interval = "10s";
            metrics_path = "/metrics/explorer-python-api";
            static_configs = [{
              targets = [ "explorer-ip" ];
              labels = { alias = "explorer-python-api"; };
            }];
          }
        ];
      };
    };
  }) // (lib.optionalAttrs globals.withExplorer {
    explorer = {
      deployment.ec2 = {
        region = "eu-central-1";
        ebsInitialRootDiskSize = 100;
      };
      imports = [
        xlarge
        ../roles/explorer.nix
      ]
      # TODO: remove module when the new explorer is available
      ++ lib.optional (globals.withLegacyExplorer) ../roles/explorer-legacy.nix;

      services.monitoring-exporters.extraPrometheusExportersPorts = [ 12798 ];
      node = {
        roles.isExplorer = true;
        org = "IOHK";
        nodeId = 99;
      };
    };
  }) // {
    # 1.3.0 tag
    staging-1 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 11;
      };
      services.cardano-node = rec {
        environmentName = "staging";
        producers = globals.environments.${environmentName}.edgeNodes;
      };
    };

    # 1.3.0 plus no logs, rough patched (cherry pick)
    staging-2 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test-no-log-rough.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 12;
      };
      services.cardano-node = rec {
        environmentName = "staging";
        producers = globals.environments.${environmentName}.edgeNodes;
        #haskellArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
      };
    };

    # 1.3.0 plus no logs, config option
    staging-3 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 13;
      };
      services.cardano-node = rec {
        environmentName = "staging";
        producers = globals.environments.${environmentName}.edgeNodes;
        #haskellArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
        logging = false;
      };
    };

    # 1.3.0 plus no logs, cardano-node PR #454
    staging-4 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test-PR-454.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 14;
      };
      services.cardano-node = rec {
        environmentName = "staging";
        producers = globals.environments.${environmentName}.edgeNodes;
        #haskellArgs = [ "+RTS" "-N2" "-A10m" "-qg" "-qb" "-M3G" "-RTS" ];
      };
    };

    testnet-1 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 21;
      };
      services.cardano-node = rec {
        environmentName = "testnet";
        producers = globals.environments.${environmentName}.edgeNodes;
      };
    };
    shelley-1 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 31;
      };
      services.cardano-node = rec {
        environmentName = "shelley_staging";
        producers = globals.environments.${environmentName}.edgeNodes;
      };
    };
    mainnet-1 = {
      deployment.ec2.region = "eu-central-1";
      imports = [
        medium
        ../roles/relay-test.nix
      ];
      node = {
        roles.isCardanoRelay = true;
        org = "IOHK";
        nodeId = 41;
      };
      services.cardano-node = rec {
        environmentName = "mainnet";
        producers = globals.environments.${environmentName}.edgeNodes;
      };
    };
  };

  nodes = mapAttrs (_: mkNode) (cardanoNodes // otherNodes);

  mkCoreNode = def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoCore = true;
        inherit (def) org nodeId;
      };
      deployment.ec2.region = def.region;
      imports = [ medium ../roles/core.nix ];
      services.cardano-node = {
        inherit (def) producers;
      };
    };
  };

  mkRelayNode = def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoRelay = true;
        inherit (def) org nodeId;
      };
      services.cardano-node = {
        inherit (def) producers;
      };
      deployment.ec2.region = def.region;
      imports = [
        medium
        ../roles/relay.nix
      ];
    };
  };

  mkByronProxyNode = def: {
    inherit (def) name;
    value = {
      node = {
        roles.isByronProxy = true;
        inherit (def) org nodeId;
      };
      deployment.ec2.region = def.region;
      imports = [
        medium
        ../roles/byron-proxy.nix
      ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];

      services.monitoring-exporters.extraPrometheusExportersPorts = [ globals.byronProxyPrometheusExporterPort ];

    };
  };

  mkLegacyCoreNode = i: def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoLegacyCore = true;
        coreIndex = i;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ medium ../roles/legacy-core.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes;
    };
  };

  mkLegacyRelayNode = def: {
    inherit (def) name;
    value = {
      node = {
        roles.isCardanoLegacyRelay = true;
        inherit (def) org;
      };
      deployment.ec2.region = def.region;
      imports = [ medium ../roles/legacy-relay.nix ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];
    };
  };

  mkNode = args:
    recursiveUpdate {
      deployment.targetEnv = targetEnv;
      nixpkgs.overlays = pkgs.cardano-ops-overlays;
    } args;

in {
  network.description = "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
