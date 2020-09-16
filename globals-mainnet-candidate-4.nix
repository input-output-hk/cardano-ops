pkgs: {

  deploymentName = "mainnet-candidate-4";

  environmentName = "mainnet_candidate_4";

  topology = import ./topologies/mainnet-candidate-4.nix pkgs;

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

  alertChainDensityLow = "60";
  alertMemPoolHigh = "190";
  alertTcpHigh = "150";
  alertTcpCrit = "180";
}
