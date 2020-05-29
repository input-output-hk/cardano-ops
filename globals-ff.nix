pkgs: {

  deploymentName = "ff";

  topology = import ./topologies/ff.nix pkgs;

  withExplorer = false;
  withLegacyExplorer = false;

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
}
