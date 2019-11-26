self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "rc-staging";

    domain = "awstest.iohkdev.io";

    configurationKey = "mainnet_dryrun_full";

    environment = "staging";

    topology = import ./topologies/staging.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "iohk";
          "Emurgo" = "fifth-party";
          "CF" = "third-party";
          dns = "dns";
        };
      };
    };
  };
}
