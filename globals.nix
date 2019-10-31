self: super: {
  globals = rec {
    static = import ./static;

    deploymentName = "cardano-ops-testing";

    domain = "${deploymentName}.aws.iohkdev.io";

    systemStart = 0;

    configurationKey = "mainnet_staging_short_epoch_full";

    ec2 = {
      credentials = {
        accessKeyId = builtins.getEnv "AWS_ACCESS_KEY_ID";
      };
    };
  };
}
