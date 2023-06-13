# Topology file for a simple testnet consisting of BFT nodes and stakepool nodes.
#
# See attributes `bftNodeRegionNames` and `poolRegionNames` to understand how
# to customize the number of nodes in the network, and the regions in which
# they are deployed.
#
# * Debugging the topology
#
# You can use `nix eval` to query the different attributes of the topology and
# check that their values match your expectations.
#
# > nix eval '(with import ./nix {}; with lib;  map (x: x.name) globals.topology.coreNodes)'
#
pkgs: with pkgs; with lib; with topology-lib;
let
  regions = {
    a = {
      name = "eu-central-1";
      minRelays = 1;
    };

    b = {
      name = "us-east-2";
      minRelays = 1;
    };

    c = {
      name = "ap-southeast-1";
      minRelays = 1;
    };

    # d = { name = "eu-west-2";      /* Europe (London)          */ };
  };
  bftCoreNodes =
    let
      # The region names will determine the number of BFT nodes. These names
      # should belong to `attrNames regions`.
      bftNodeRegionNames = [];
      # BFT node specifications, which will be used to create BFT nodes.
      bftNodeSpecs =
        genList
        (i: { region = builtins.elemAt bftNodeRegionNames i;
              org    = "IOHK";
              nodeId = i + 1;
            }
        )
        (length bftNodeRegionNames);
      bftNodes = fullyConnectNodes (
        map ({region, org, nodeId}:
          mkBftCoreNode region 1 { inherit org nodeId;}
        ) bftNodeSpecs);
      in bftNodes;

  relayNodes = map (composeAll [
    (forNodes {
      services.cardano-node = {
        useNewTopology = true;
        usePeersFromLedgerAfterSlot = -1;
      };
    } ["rel-a-1"])
  ]) (map (withModule {
    services.cardano-node.shareIpv6port = false;
  }) (
    mkRelayTopology {
    inherit regions;
    coreNodes = stakingPoolNodes;
    autoscaling = false;
    maxProducersPerNode = 20;
    maxInRegionPeers = 5;
  }));

  stakingPoolNodes =
    let
      # The region names determine the number of stake pools. These names
      # should belong to `attrNames regions`.
      poolRegionNames = [ "a" "b" "c" ];
      # Stake pool specifications, which will be used to create stake pools.
      poolSpecs =
        genList
        (i: { region   = builtins.elemAt poolRegionNames i;
              nodeName = "IOHK" + toString ((length bftCoreNodes) + i + 1);
              nodeId   = (length bftCoreNodes) + i + 1;
            }
        )
        (length poolRegionNames);
      pools = fullyConnectNodes (
        map ({region, nodeName, nodeId}:
          mkStakingPool region 1 nodeName {nodeId = nodeId;}
        ) poolSpecs);
    in
      pools;

  coreNodes = bftCoreNodes ++ stakingPoolNodes;
in {
  inherit coreNodes relayNodes regions;

  monitoring.services.oauth2_proxy.enable = false;
}
