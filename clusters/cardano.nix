{ targetEnv
, medium
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
    // listToAttrs (map mkRelayNode relayNodes)
    // listToAttrs (map mkByronProxyNode byronProxies);

  otherNodes = {
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

      # TODO: remove once explorer exports metrics at path `/metrics`
      services.prometheus = {
        scrapeConfigs = [
          {
            job_name = "explorer";
            scrape_interval = "10s";
            metrics_path = "/";
            static_configs = [{
              targets = [ "explorer-ip:8080" ];
              labels = { alias = "explorer-ip-8080"; };
            }];
          }
        ];
      };
    };

    explorer = {
      deployment.ec2.region = "eu-central-1";
      imports = [ medium ../roles/explorer.nix ];

      # TODO: Add 12798 when prometheus binding is a parameter
      services.monitoring-exporters.extraPrometheusExportersPorts = [ 8080 ];
      node = {
        roles.isExplorer = true;
        org = "IOHK";
        nodeId = 99;
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

        # TODO: remove module when prometheus binding is a parameter
        ../modules/nginx-monitoring-proxy.nix
      ];
      services.nginx-monitoring-proxy = {
        proxyName = "localproxy";
        listenPort = globals.cardanoNodePrometheusExporterPort;
        listenPath = "/metrics";
        proxyPort = 12797;
        proxyPath = "/metrics";
      };
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

        # TODO: remove module when prometheus binding is a parameter
        ../modules/nginx-monitoring-proxy.nix
      ];
      services.cardano-node-legacy.staticRoutes = def.staticRoutes or [];
      services.cardano-node-legacy.dynamicSubscribe = def.dynamicSubscribe or [];

      services.monitoring-exporters.extraPrometheusExportersPorts = [ globals.byronProxyPrometheusExporterPort ];
      services.nginx-monitoring-proxy = {
        proxyName = "localproxy";
        listenPort = globals.byronProxyPrometheusExporterPort;
        listenPath = "/metrics";
        proxyPort = 12796;
        proxyPath = "/metrics";
      };

      # TODO: modify/remove when prometheus binding is a parameter
      services.byron-proxy.logger.configFile =
        let
          byronProxySrc = sourcePaths.cardano-byron-proxy;
          loggerUnmodFile = byronProxySrc + "/cfg/logging.yaml";
          loggerUnmod = __readFile loggerUnmodFile;
          loggerMod = lib.replaceStrings [ "hasPrometheus: 12799" ] [ "hasPrometheus: 12796" ] loggerUnmod;
          loggerModFile = __toFile "logging-prom-12796.yaml" loggerMod;
        in
          loggerModFile;
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
