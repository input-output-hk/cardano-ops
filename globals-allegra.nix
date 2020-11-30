pkgs: {

  deploymentName = "allegra";

  withFaucet = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSmash = false;
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
