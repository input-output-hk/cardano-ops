self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "mainnet";

    domain = "cardano-mainnet.iohk.io";

    configurationKey = "mainnet_dryrun_full";

    environment = "mainnet";

    topology = import ./topologies/mainnet.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "mainnet-iohk";
          "Emurgo" = "mainnet-emurgo";
          "CF" = "mainnet-cf";
          dns = "mainnet-iohk";
        };
      };
    };
  };
}
