pkgs: {

  deploymentName = "staging-shelley";

  environmentName = "shelley_staging";

  topology = import ./topologies/staging-shelley.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
