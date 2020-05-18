pkgs: { resources, config, ... }:
let
  assetLockFile = if (builtins.pathExists ../static/asset-locked-addresses.txt) then ../static/asset-locked-addresses.txt else null;

in {

  imports = [
    pkgs.cardano-ops.modules.base-legacy-service
  ];

  services.cardano-node-legacy.nodeType = "core";
  services.cardano-node-legacy.assetLockFile = assetLockFile;

  deployment.keys.cardano-node = {
    keyFile = ../keys + "/${toString config.node.nodeId}.sk";
    user = "cardano-node";
    destDir = "/var/lib/keys";
  };

  systemd.services."cardano-node-legacy" = {
    after = [ "cardano-node-key.service" ];
    wants = [ "cardano-node-key.service" ];
  };

}
