pkgs: {

  deploymentName = "testnet";

  domain = "cardano-testnet.iohkdev.io";

  environmentName = "testnet";

  topology = import ./topologies/testnet.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "default";
      };
    };
  };
}
