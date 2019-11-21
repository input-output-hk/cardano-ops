self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "staging-shelley";

    domain = "${deploymentName}.aws.iohkdev.io";

    configurationKey = "shelley_staging_full";

    environment = "shelley_staging";

    topology = import ./topologies/staging-shelley.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "default";
          "Emurgo" = "default";
          "CF" = "default";
        };
      };
    };
  };
}
