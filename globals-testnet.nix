self: super: {
  globals = (import ./globals-defaults.nix self)// rec {

    static = import ./static;

    deploymentName = "testnet";

    domain = "cardano-testnet.iohkdev.io";

    environmentName = "testnet";

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
