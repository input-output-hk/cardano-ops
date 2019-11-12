{ resources, config, ... }:
{

  imports = [
    ../modules/base-legacy-service.nix
  ];

  services.cardano-node-legacy.nodeType = "core";

  deployment.ec2.securityGroups = [
    resources.ec2SecurityGroups."allow-cardano-legacy-node-${config.node.region}"
  ];

  deployment.keys.cardano-node = {
    keyFile = ../keys + "/${toString config.node2.coreIndex}.sk";
    user = "cardano-node";
    destDir = "/var/lib/keys";
  };

  systemd.services."cardano-node-legacy" = {
    after = [ "cardano-node-key.service" ];
    wants = [ "cardano-node-key.service" ];
  };

}
