{ region, org, pkgs, nodes, lib, ... }:
with lib;
let
  inherit (pkgs.globals) cardanoNodePort topology maxPrivilegedRelays;
  inherit (topology) coreNodes relayNodes byronProxies;
  privateRelayNodes = topology.privateRelayNodes or [];
  concernedCoreOrPrivateNodes = map (c: c.name) (filter (c: c.region == region && c.org == org) (coreNodes ++ privateRelayNodes));
  connectingCoreNodes = filter (c: any (p: builtins.elem p concernedCoreOrPrivateNodes) c.producers) coreNodes;
  connectingRelays = partition (r: any (p: builtins.elem p concernedCoreOrPrivateNodes) r.producers) (relayNodes ++ privateRelayNodes);
  privilegedRelays = lib.take maxPrivilegedRelays
    (builtins.trace (let nbCrelays = length connectingRelays.right;
      in if (nbCrelays > maxPrivilegedRelays)
      then "WARNING: ${toString (nbCrelays - maxPrivilegedRelays)} relays (${toString (map (n: n.name) (drop maxPrivilegedRelays connectingRelays.right))}) won't be able to connect to core/private nodes under ${org}/${region}"
      else "${org}/${region}: ${toString (maxPrivilegedRelays - nbCrelays)} relay nodes margin before hitting `maxPrivilegedRelays` limit")
    (connectingRelays.right ++ connectingRelays.wrong));
  peers = map (n: n.name) (builtins.concatLists [ connectingCoreNodes privilegedRelays byronProxies ])
    # Allow explorer to connect directly to core nodes if there is no relay nodes.
    ++ (lib.optional (nodes ? explorer && relayNodes == []) "explorer");
in
  pkgs.iohk-ops-lib.physical.aws.security-groups.allow-to-tcp-port
    "cardano" cardanoNodePort peers {
      inherit region org pkgs;
    }
