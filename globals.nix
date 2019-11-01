self: super: {
  globals = rec {
    static = import ./static;

    deploymentName = "cardano-ops-testing";

    domain = "${deploymentName}.aws.iohkdev.io";

    systemStart = 0;

    configurationKey = "mainnet_staging_short_epoch_full";

    environment = "stagingshelley";

    ec2 = {
      credentials = {
        accessKeyId = "cardano-deployer";
      };
    };
  };
}
