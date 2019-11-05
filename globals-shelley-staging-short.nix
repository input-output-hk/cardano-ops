self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "staging-shelley-short";

    domain = "${deploymentName}.aws.iohkdev.io";

    systemStart = 0;

    configurationKey = "mainnet_staging_short_epoch_full";

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
