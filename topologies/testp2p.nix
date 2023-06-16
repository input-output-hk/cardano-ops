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
      networking.localCommands = ''
        for i in $(seq 1 ${toString pkgs.globals.nbInstancesPerRelay}); do
          ip -6 address add ::127.0.0.$i/96 dev lo || true
        done
      '';
      services.cardano-node = {
        # Options to enable p2p relays in mixed topology cluster:

        # To ensure non-systemd socket activated instances bind the same port on the machine, ie: 3001,
        # This ensures they all receive incoming traffic.
        # Since systemd sockets are not used, there is no so_reuseport socket UID conflict.
        # For non-mingw32 hosts, node enables so_reuseport for socket configuration by default.
        shareIpv4port = true;

        # The typical ipv4 legacy cluster topology uses systemd socket activation with an ipv6
        # localhost listener of ::1 with different port binding to enable intra-machine node peering.
        # Without systemd socket activation, node cli only parameterizes a single port option that is used for both ipv4 and ipv6.
        # Enabling this option will ensure topology port declaration for intra-machine peering uses the same port.
        # This infers, though, that the ipv6 addresses for each instance on a machine will need to be different.
        shareIpv6port = lib.mkForce true;

        # Per above, we wish to increment the ipv6 address for each instance to create a unique intramachine node listener.
        shareIpv6Address = false;

        # Turn systemd socket activation off due to an so_reuseport UID kernel conflict when binding sockets for re-use as non-root user.
        systemdSocketActivation = lib.mkForce false;

        # Use p2p
        useNewTopology = true;

        # Transform any p2p multi-member accessPoints groups into single member accessPoints.
        useSingleMemberAccessPoints = true;

        # Make 3rd party producers localRoots rather than publicRoots for a 1:1 equivalency with legacy topology.
        useInstancePublicProducersAsProducers = true;

        # Don't use any chain source outside of declared localRoots
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
