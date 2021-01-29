pkgs: {

  deploymentName = "mary-qa";
  environmentName = "mary_qa";

  withFaucet = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSmash = true;
  withSubmitApi = true;
  faucetHostname = "faucet";

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };
}
