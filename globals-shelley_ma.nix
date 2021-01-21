pkgs: {

  deploymentName = "shelley-ma";
  environmentName = "shelley_ma";

  withFaucet = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSmash = false;
  withSubmitApi = true;
  faucetHostname = "faucet";

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
