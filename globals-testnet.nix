self: super: {
  globals = import ./globals-defaults.nix // rec {

    static = import ./static;

    deploymentName = "testnet";

    domain = "cardano-testnet.iohkdev.io";

    configurationKey = "testnet_full";

    environment = "testnet";

    topology = import ./topologies/testnet.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          "IOHK" = "default";
          dns = "default";
        };
      };
    };
  };
}
