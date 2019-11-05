{ region, org, pkgs, nodes, lib, ... }:
with lib;
let
  inherit (pkgs.globals) cardanoNodeLegacyPort topology;
  inherit (topology) legacyCoreNodes legacyRelayNodes byronProxies;
  peers = map (n: n.name) (legacyCoreNodes ++ legacyRelayNodes ++ byronProxies);
in
  pkgs.iohk-ops-lib.physical.aws.security-groups.allow-to-tcp-port
    "cardano-legacy" cardanoNodeLegacyPort peers {
      inherit region org pkgs;
    }
