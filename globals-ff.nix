pkgs: {

  deploymentName = "ff";

  topology = import ./topologies/ff.nix pkgs;

  withExplorer = true;
  withLegacyExplorer = false;
  withHighLoadRelays = true;
  withSmash = true;

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
