self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "staging-shelley-short";

    domain = "${deploymentName}.aws.iohkdev.io";

    configurationKey = "shelley_staging_short_full";

    environment = "shelley_staging_short";

    topology = import ./topologies/staging-shelley-short.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "dev-deployer";
          "dns" = "default";
        };
      };
    };
  };
}
