pkgs:

with pkgs.lib;
let
  ## Stub, to enable use of globals-bench-common.nix
  benchmarkingProfile = {
  };

  inherit (import ./globals-bench-common.nix { inherit pkgs benchmarkingProfile; })
    mkNodeOverlay;

  mkRegionRelayConnection =
    region: {
      addr = "${region}.relays-new.cardano-mainnet.iohk.io";
      port = 3001;
      valency = 3;
    };
in
{

  networkName = "Benchmarking-configured mainnet canary";
  deploymentName = "maincanary";
  environmentName = "mainnet";

  sourcesJsonOverride = ./nix/sources.bench.json;

  relaysNew = "relays.${pkgs.globals.domain}";
  nbInstancesPerRelay = 1;

  withCardanoDBExtended = false;
  withExplorer = false;
  withMonitoring = false;

  topology =
    { coreNodes  = [];
      relayNodes = [
        ({
          name = "maincanary";
          nodeId = 0;
          region = "eu-central-1";
          org = "IOHK";
          producers =
            map mkRegionRelayConnection
              [ "asia-pacific"
                "europe"
                "north-america"
              ];

          ###
          documentation = {
            man.enable = false;
            doc.enable = false;
          };
          networking.firewall.allowPing = mkForce true;
          services.cardano-node = {
            package = mkForce pkgs.cardano-node-eventlogged;
            extraNodeConfig = setupNodeConfig { TraceBlockFetchProtocol = true; };
          };
          systemd.services.dump-registered-relays-topology.enable = mkForce false;
        }
        // ## Mainnet relay with minimal benchmarking extras.
        mkNodeOverlay {} {})
      ];
    };

  ec2 = with pkgs.iohk-ops-lib.physical.aws;
    {
      instances = {
        core-node = c5-2xlarge;
        relay-node = c5-2xlarge;
      };
      credentials = {
        accessKeyIds = {
          IOHK = "dev-deployer";
          dns = "dev-deployer";
        };
      };
    };

  nodeDbDiskAllocationSize = 200;
}
