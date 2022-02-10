pkgs: {

  deploymentName = "shelley-qa-p2p";

  environmentName = "shelley_qa";

  nbInstancesPerRelay = 1;

  withExplorer = false;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
