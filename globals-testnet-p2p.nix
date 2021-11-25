pkgs: {

  deploymentName = "testnet-p2p";
  environmentName = "testnet";
  nbInstancesPerRelay = 1;
  withExplorer = false;

  alertChainDensityLow = "50";

  overlay = self: super: {
    sourcePaths = super.sourcePaths // {
      # Use p2p branch everywhere:
      cardano-node = super.sourcePaths.cardano-node-service;
    };
  };

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };
}
