
pkgs: {

  imports = [
    pkgs.cardano-ops.modules.base-service
  ];

  services.cardano-node.nodeConfig = {
    # The maximum number of used peers when fetching newly forged blocks.
    MaxConcurrencyDeadline = 4;
  };

}
