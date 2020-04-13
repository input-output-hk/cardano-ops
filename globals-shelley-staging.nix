pkgs: {

  deploymentName = "staging-shelley";

  environmentName = "shelley_staging";

  withExplorerAliases = [];

  withFaucet = true;
  faucetHostname = "faucet";

  withHighLoadRelays = true;

  topology = import ./topologies/staging-shelley.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
