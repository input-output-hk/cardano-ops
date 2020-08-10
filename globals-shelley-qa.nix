pkgs: {

  deploymentName = "shelley-qa";
  environmentName = "shelley_qa";

  topology = import ./topologies/shelley-qa.nix;
  environmentConfig = pkgs.iohkNix.cardanoLib.environments.shelley_qa;

  withFaucet = true;
  withExplorer = true;
  withCardanoDBExtended = false;
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
