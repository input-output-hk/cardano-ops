pkgs: {

  deploymentName = "shelley-qa";
  environmentName = "shelley_qa";

  topology = import ./topologies/shelley-qa.nix pkgs;
  environmentConfig = pkgs.iohkNix.cardanoLib.environments.shelley_qa;

  withFaucet = true;
  withExplorer = true;
  withCardanoDBExtended = true;
  withSmash = true;
  withSubmitApi = true;
  faucetHostname = "faucet";
  nbInstancesPerRelay = 2;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
