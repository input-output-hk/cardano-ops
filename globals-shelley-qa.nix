pkgs: with pkgs; {

  deploymentName = "shelley-qa";
  environmentName = "shelley_qa";

  relaysNew = globals.environmentConfig.relaysNew;

  withFaucet = true;
  withExplorer = true;
  explorerBackendsInContainers = true;
  withSmash = true;
  withSubmitApi = true;
  faucetHostname = "faucet";
  minCpuPerInstance = 1;
  minMemoryPerInstance = 4;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
