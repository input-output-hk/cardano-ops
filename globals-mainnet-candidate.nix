pkgs: {

  deploymentName = "mainnet-candidate";

  environmentName = "mainnet_candidate";

  topology = import ./topologies/mainnet-candidate.nix pkgs;

  withExplorer = true;
  withHighLoadRelays = true;
  withSmash = true;
  withSubmitApi = true;

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
