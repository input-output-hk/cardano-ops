self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "staging-shelley-short";

    domain = "${deploymentName}.aws.iohkdev.io";

    # Saturday, November 16, 2019 1:00:00 AM
    systemStart = 1573866000;


    configurationKey = "shelley_staging_short_full";

    environment = "shelley_staging_short";

    topology = import ./topologies/staging-shelley-short.nix;

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
