{ region, org, pkgs, nodes, lib, ... }:
with lib;
let
  inherit (pkgs.globals) cardanoNodePort topology maxPrivilegedRelays;
  inherit (topology) coreNodes relayNodes byronProxies;
  privateRelayNodes = topology.privateRelayNodes or [];
  privilegedRelays = lib.take maxPrivilegedRelays relayNodes;
  peers = map (n: n.name) (builtins.concatLists [ coreNodes privateRelayNodes privilegedRelays byronProxies ])
    # Allow explorer to connect directly to core nodes if there is no relay nodes.
    ++ (lib.optional (nodes ? explorer && relayNodes == []) "explorer");
in
  pkgs.iohk-ops-lib.physical.aws.security-groups.allow-to-tcp-port
    "cardano" cardanoNodePort peers {
      inherit region org pkgs;
    }
