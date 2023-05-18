
pkgs: with pkgs; {config, ...}: {

  imports = [
    cardano-ops.modules.base-service
    ../modules/tcpdump.nix
  ];

  deployment.ec2.ebsInitialRootDiskSize = globals.systemDiskAllocationSize
    + (globals.nodeDbDiskAllocationSize * config.services.cardano-node.instances);

  services.cardano-node = {
    instances = lib.mkDefault globals.nbInstancesPerRelay;
    totalCpuCores = lib.mkDefault config.node.cpus;
    extraServiceConfig = _: {
      # Since multiple node instances might monopolize CPU, preventing ssh access, lower nice priority:
      serviceConfig.Nice = 5;
    };
  };

}
