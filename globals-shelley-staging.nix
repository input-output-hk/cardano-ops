self: super: {
  globals = (import ./globals-defaults.nix self) // rec {

    static = import ./static;

    deploymentName = "staging-shelley";

    domain = "${deploymentName}.dev.iohkdev.io";

    environmentName = "shelley_staging";

    topology = import ./topologies/staging-shelley.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "dev-deployer";
          dns = "dev-deployer";
        };
      };
    };
  };
}
