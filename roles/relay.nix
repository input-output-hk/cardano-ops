
pkgs: with pkgs; {config, ...}: {

  imports = [
    cardano-ops.modules.base-service
  ];

  deployment.ec2.ebsInitialRootDiskSize = globals.systemDiskAllocationSize
    + (globals.nodeDbDiskAllocationSize * config.services.cardano-node.instances);

  services.cardano-node = {
    instances = lib.mkDefault globals.nbInstancesPerRelay;
    nodeConfig = {
      # The maximum number of used peers when fetching newly forged blocks.
      MaxConcurrencyDeadline = 4;
    };
    extraServiceConfig = _: {
      # Since multiple node instances might monopolize CPU, preventing ssh access, lower nice priority:
      serviceConfig.Nice = 5;
    };
  };

}
