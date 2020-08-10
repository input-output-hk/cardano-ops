pkgs: {

  deploymentName = "shelley-testnet";

  environmentName = "shelley_testnet";

  topology = import ./topologies/shelley-testnet.nix pkgs;

  withExplorer = true;
  withHighLoadRelays = true;
  withSmash = true;

  withFaucet = true;
  faucetHostname = "faucet";

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };

  alertTcpHigh = "150";
  alertTcpCrit = "180";
}
