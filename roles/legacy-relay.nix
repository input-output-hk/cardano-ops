pkgs: { options, config, nodes, resources,  ... }:
{

  imports = [
    pkgs.cardano-ops.modules.base-legacy-service
  ];

  services.cardano-node-legacy.nodeType = "relay";

}
