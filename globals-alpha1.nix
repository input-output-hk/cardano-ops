pkgs: {

  deploymentName = "alpha1";

  topology = import ./topologies/alpha1.nix;

  withExplorer = false;
  withLegacyExplorer = false;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
