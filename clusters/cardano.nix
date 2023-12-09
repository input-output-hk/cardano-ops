{ pkgs
, instances
, ...
}:
with pkgs;
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) coreNodes relayNodes;
  privateRelayNodes = topology.privateRelayNodes or [];
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1 concatLists;

  customNodes = mapAttrs mkCustomNode
    (builtins.removeAttrs topology ["privateRelayNodes" "relayNodes" "coreNodes" "regions" "testNodes"]);

  cardanoNodes = listToAttrs (concatLists [
    (map mkCoreNode coreNodes)
    (map mkRelayNode (relayNodes ++ privateRelayNodes))
    (map mkTestNode (topology.testNodes or []))
  ]);

  otherNodes = (lib.optionalAttrs globals.withMonitoring {
    monitoring = let def = (topology.monitoring or {}); in mkNode {
      deployment.ec2.region = def.region or "eu-central-1";
      imports = [
        (def.instance or instances.monitoring)
        iohk-ops-lib.roles.monitor
        (cardano-ops.modules.monitoring-cardano pkgs)
      ];
      node = {
        roles = {
          isMonitor = true;
          class = "monitoring";
        };
        org = def.org or "IOHK";
      };
      services.monitoring-services.logging = false;
      services.prometheus.scrapeConfigs = lib.optionals globals.withExplorer [
        (mkBlackboxScrapeConfig "blackbox_explorer_graphql" [ "https_explorer_post_2xx" ] [ "https://${globals.explorerHostName}/graphql" ])
        (mkBlackboxScrapeConfig "blackbox_explorer_frontend" [ "https_2xx" ] [ "https://${globals.explorerHostName}" ])
        (mkBlackboxScrapeConfig "blackbox_explorer_graphql_healthcheck" [ "htts_2xx" ] (map (member: "http://explorer-${member}-ip:9999/healthz") (builtins.attrNames globals.explorerBackends)))
      ];
      # TODO: activate for 21.05
      #services.grafana.declarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];
    } def;
  }) // (lib.optionalAttrs globals.withExplorer ({
    explorer = let def = (topology.explorer or {}); in mkNode {
      _file = ./cardano.nix;
      deployment.ec2 = {
        region = def.region or "eu-central-1";
        ebsInitialRootDiskSize = lib.mkIf globals.explorerBackendsInContainers
          (if globals.withHighCapacityExplorer then 1000 else 100);
      };
      imports = [
        (def.instance or (if globals.explorerBackendsInContainers
          then instances.explorer
          else instances.explorer-gw))
        cardano-ops.roles.explorer-gateway
      ];

      node = {
        roles = {
          isExplorer = true;
          class = if globals.explorerBackendsInContainers then "explorer" else "explorer-gw";
        };
        org = def.org or "IOHK";
        nodeId = def.nodeId or 99;
      };
    } def;
  } // (lib.optionalAttrs (!globals.explorerBackendsInContainers)
    (lib.mapAttrs' (z: variant: lib.nameValuePair "explorer-${z}"
      (let def = (topology."explorer-${z}" or {}); in mkNode {
        _file = ./cardano.nix;
        deployment.ec2 = rec {
          region = def.region or "eu-central-1";
          zone = "${region}${z}";
          ebsInitialRootDiskSize = (if globals.withHighCapacityExplorer then 1000 else 100);
        };
        imports = [
          (def.instance or instances.explorer)
          (cardano-ops.roles.explorer variant)
        ];

        node = {
          roles = {
            isExplorerBackend = true;
            class = "explorer";
          };
          org = def.org or "IOHK";
          nodeId = def.nodeId or 99;
        };
      } def)
    ) globals.explorerBackends)
  ))) // (lib.optionalAttrs globals.withSnapshots {
    snapshots = let def = (topology.snapshots or {}); in mkNode {
      _file = ./cardano.nix;
      deployment.ec2 = {
        region = def.region or "eu-central-1";
        ebsInitialRootDiskSize = if globals.withHighCapacityExplorer then 1000 else 100;
      };
      imports = [
        (def.instance or instances.snapshots)
        cardano-ops.roles.snapshots
        (pkgs: let
          iohkNix812 = import (import ../nix/sources.nix { inherit pkgs; })."iohk-nix-node-8.1.2" {};
        in {
          # Correct the difference between the new iohk-nix for 8.7.2 and the legacy iohk-nix still required for dbsync on node 8.1.2
          services.cardano-node = {
            useNewTopology = false;
            environments = {
              "${globals.environmentName}" = iohkNix812.cardanoLib.environments.${globals.environmentName};
            };
            nodeConfig = iohkNix812.cardanoLib.environments.${globals.environmentName}.nodeConfig;
            extraNodeConfig.EnableP2P = false;
            producers = pkgs.lib.mkForce [];
            publicProducers = pkgs.lib.mkForce [{accessPoints = [{address = "europe.relays-new.cardano-mainnet.iohk.io"; port = 3001; valency = 2;}];}];
          };

          services.cardano-db-sync = {
            environment = iohkNix812.cardanoLib.environments.${globals.environmentName};
            logConfig = iohkNix812.cardanoLib.defaultExplorerLogConfig // { PrometheusPort = globals.cardanoExplorerPrometheusExporterPort; };
          };
        })
      ];

      node = {
        roles = {
          isSnapshots = true;
          class = "snapshots";
        };
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
        (def.instance or instances.faucet)
        cardano-ops.roles.faucet
      ];
      node = {
        roles = {
          isFaucet = true;
          class = "faucet";
        };
        org = "IOHK";
        nodeId = def.nodeId or 99;
      };
    } def;
  }) // (lib.optionalAttrs globals.withMetadata {
    metadata = let def = (topology.metadata or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        (def.instance or instances.metadata)
        cardano-ops.roles.metadata
      ];
      node = {
        roles = {
          isMetadata = true;
          class = "metadata";
        };
        org = def.org or "IOHK";
      };
    } def;
  });

  nodes = customNodes // cardanoNodes // otherNodes;

  mkCoreNode =  def: let
    isCardanoDensePool = def.pools or null != null && def.pools > 1;
  in {
    inherit (def) name;
    value = mkNode {
      _file = ./cardano.nix;
      node = {
        inherit (def) org nodeId;
        roles = {
          isCardanoCore = true;
          class = if isCardanoDensePool then "dense-pool" else "pool";
          inherit isCardanoDensePool;
        };
      };
      deployment.ec2.region = def.region;
      imports = [
        (def.instance or (if isCardanoDensePool
          then instances.dense-pool
          else instances.core-node))
        (cardano-ops.roles.core def.nodeId)
      ];
      services.cardano-node.allProducers = def.producers;
    } def;
  };

  mkRelayNode = def: let
    highLoad = def.withHighLoadRelays or globals.withHighLoadRelays;
  in {
    inherit (def) name;
    value = mkNode {
      _file = ./cardano.nix;
      node = {
        roles = {
          isCardanoRelay = true;
          class = if highLoad then "high-load-relay" else "relay";
        };
        inherit (def) org nodeId;
      };
      services.cardano-node.allProducers = def.producers;
      deployment.ec2.region = def.region;
      imports = [(def.instance or instances.relay-node)] ++ (
        if highLoad
        then [cardano-ops.roles.relay-high-load]
        else [cardano-ops.roles.relay]
      );
    } def;
  };

  # Load client with optimized NVME disks, for prometheus monitored clients syncs
  mkTestNode = def: {
    inherit (def) name;
    value = mkNode {
      node = {
        inherit (def) org;
        roles.class = "test";
      };
      deployment.ec2.region = def.region;
      imports = [
        (def.instance or instances.test-node)
        cardano-ops.roles.load-client
      ];
    } def;
  };

  mkCustomNode = name: def: mkNode {
    node = {
      roles = {
        isCustom = true;
        class = "custom";
      };
      org = def.org or "IOHK";
      nodeId = def.nodeId or 99;
    };
    deployment.ec2 = {
      region = def.region or "eu-central-1";
    };
    imports = [(def.instance or instances.core-node)];
  } def;

  mkNode = args: def:
    recursiveUpdate (
      recursiveUpdate {
        # TODO: review machine deployments successful post hydra shutdown and remove this line
        deployment.hasFastConnection = true;
        deployment.targetEnv = instances.targetEnv;
        nixpkgs.pkgs = pkgs;
      } (args // {
        imports = (args.imports or []) ++ (def.imports or []);
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
        "stakePool"
        "instance"
        "pools"
        "ticker"
        "public"
      ]);

in {
  network.description =
    globals.networkName
      or
    "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
