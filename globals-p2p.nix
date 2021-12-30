pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "p2p";

  withFaucet = true;

  explorerBackends = {
    a = explorer12;
  };
  explorerBackendsInContainers = true;

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
