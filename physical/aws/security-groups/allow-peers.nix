{ region, org, pkgs, nodes, lib, ... }:
with lib;
let
  inherit (pkgs.globals) cardanoNodePort topology maxPrivilegedRelays;
  inherit (topology) coreNodes relayNodes byronProxies;
  concernedCoreNodes = map (c: c.name) (filter (c: c.region == region && c.org == org) coreNodes);
  privateRelayNodes = topology.privateRelayNodes or [];
  concernedRelays = partition (r: any (p: builtins.elem p concernedCoreNodes) r.producers) (privateRelayNodes ++ relayNodes);
  privilegedRelays = lib.take maxPrivilegedRelays (concernedRelays.right ++ concernedRelays.wrong);
  peers = map (n: n.name) (builtins.concatLists [ coreNodes privilegedRelays byronProxies ])
    # Allow explorer to connect directly to core nodes if there is no relay nodes.
    ++ (lib.optional (nodes ? explorer && relayNodes == []) "explorer");
in
  pkgs.iohk-ops-lib.physical.aws.security-groups.allow-to-tcp-port
    "cardano" cardanoNodePort peers {
      inherit region org pkgs;
    }
