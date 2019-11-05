{ region, org, pkgs, nodes, lib, ... }:
with lib;
let
  inherit (pkgs.globals) cardanoNodePort topology;
  inherit (topology) coreNodes relayNodes byronProxies;
  peers = map (n: n.name) (coreNodes ++ relayNodes ++ byronProxies);
in
  pkgs.iohk-ops-lib.physical.aws.security-groups.allow-to-tcp-port
    "cardano" cardanoNodePort peers {
      inherit region org pkgs;
    }
