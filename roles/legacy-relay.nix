{ options, config, nodes, resources,  ... }:
{

  imports = [
    ../modules/base-legacy-service.nix
  ];

  services.cardano-node-legacy.nodeType = "relay";

}
