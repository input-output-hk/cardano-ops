self: super: {
  globals = (import ./globals-defaults.nix self) // rec {

    static = import ./static;

    deploymentName = "mainnet";

    domain = "cardano-mainnet.iohk.io";

    environmentName = "mainnet";

    topology = import ./topologies/mainnet.nix;

    ec2 = {
      credentials = {
        accessKeyIds = {
          IOHK = "mainnet-iohk";
          Emurgo = "mainnet-emurgo";
          CF = "mainnet-cf";
          dns = "mainnet-iohk";
        };
      };
    };
  };
}
