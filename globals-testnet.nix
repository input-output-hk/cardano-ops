pkgs: {

  deploymentName = "testnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-testnet.iohkdev.io";

  withSubmitApi = true;
  withFaucet = true;
  withSmash = true;

  faucetHostname = "faucet2";
  faucetHostnameNew = "faucet";

  initialPythonExplorerDBSyncDone = true;

  environmentName = "testnet";

  topology = import ./topologies/testnet.nix pkgs;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "default";
      };
    };
  };

  relayUpdateArgs = "-m 50 -s -e devops@iohk.io";
  # Trigger relay topology refresh 12 hours before next epoch
  relayUpdateHoursBeforeNextEpoch = 12;

  alertChainDensityLow = "60";
  alertTcpHigh = "220";
  alertTcpCrit = "250";
}
