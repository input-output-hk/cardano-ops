pkgs: {

  deploymentName = "testnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-testnet.iohkdev.io";

  withExplorerAliases = [];
  withFaucet = true;
  faucetHostname = "faucet2";

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
