{ pkgs
, targetEnv
, nano
, small
, medium               # Standard relay
, xlarge               # Standard explorer
, t3-xlarge            # High load relay
, m5ad-xlarge          # Test node
, xlarge-monitor       # Standard monitor
, t3-2xlarge-monitor   # High capacity monitor
, c5-4xlarge           # High capacity explorer (postgres CPU intensive)
, ...
}:
with pkgs;
let

  inherit (globals) topology byronProxyPort;
  inherit (topology) coreNodes relayNodes;
  privateRelayNodes = topology.privateRelayNodes or [];
  inherit (lib) recursiveUpdate mapAttrs listToAttrs imap1 concatLists;

  cardanoNodes = listToAttrs (concatLists [
    (map mkCoreNode coreNodes)
    (map mkRelayNode (relayNodes ++ privateRelayNodes))
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
          ])) ++ (lib.optionals globals.withSmash [
          {
            job_name = "smash-exporter";
            scrape_interval = "10s";
            metrics_path = "/metrics2/exporter";
            static_configs = [{
              targets = [ "smash-ip" ];
              labels = { alias = "smash-exporter"; };
            }];
          }
          ]) ++ (lib.optional globals.withFaucet (
          {
            job_name = "cardano-faucet";
            scrape_interval = "10s";
            metrics_path = "/metrics";
            static_configs = [{
              targets = [ "${globals.faucetHostname}.${globals.domain}" ];
              labels = { alias = "cardano-faucet"; };
            }];
          }
          ));
          #)) ++ (lib.optional globals.withMetadataServer (
          #{
          #  job_name = "metadata-server";
          #  scrape_interval = "10s";
          #  metrics_path = "/metrics";
          #  static_configs = [{
          #    targets = [ "metadata-ip" ];
          #    labels = { alias = "metadata-server"; };
          #  }];
          #}));
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
        (if globals.withHighCapacityExplorer then c5-4xlarge else xlarge)
        cardano-ops.roles.explorer
      ];

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
  }) // (lib.optionalAttrs globals.withSmash {
    smash = let def = (topology.smash or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        xlarge
        cardano-ops.roles.smash
      ];
      node = {
        roles.isSmash = true;
        nodeId = def.nodeId or 100;
        org = "IOHK";
      };
    } def;
  }) // (lib.optionalAttrs globals.withMetadataServer {
    metadata = let def = (topology.metadataServer or {}); in mkNode {
      deployment.ec2 = {
        region = "eu-central-1";
      };
      imports = [
        medium
        cardano-ops.roles.metadata-server
      ];
      node = {
        roles.isMetadataServer = true;
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
        "stakePool"
      ]);

in {
  network.description =
    globals.networkName
      or
    "Cardano cluster - ${globals.deploymentName}";
  network.enableRollback = true;
} // nodes
