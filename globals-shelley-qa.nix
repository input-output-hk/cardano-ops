pkgs: {

  deploymentName = "shelley-qa";
  environmentName = "shelley_qa";

  relaysNew = pkgs.globals.environmentConfig.relaysNew;

  withFaucet = true;
  withExplorer = true;
  explorerBackendsInContainers = true;
  explorerBackends = with pkgs.globals; {
    a = explorer10;
    b = explorer11;
  };
  explorerActiveBackends = [ "b" ];
  withCardanoDBExtended = true;
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
