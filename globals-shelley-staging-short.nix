self: super: {
  globals = (import ./globals-defaults.nix self) // rec {

    static = import ./static;

    deploymentName = "staging-shelley-short";

    domain = "${deploymentName}.dev.iohkdev.io";

    environmentName = "shelley_staging_short";

    topology = import ./topologies/staging-shelley-short.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "dev-deployer";
          "dns" = "dev-deployer";
        };
      };
    };
  };
}
