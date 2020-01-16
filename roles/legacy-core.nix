{ resources, config, ... }:
{

  imports = [
    ../modules/base-legacy-service.nix
  ];

  services.cardano-node-legacy.nodeType = "core";

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
