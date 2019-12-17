pkgs: {

  deploymentName = "alpha2";

  topology = import ./topologies/alpha2.nix { inherit (pkgs) lib pkgs; };

  withExplorer = false;
  withLegacyExplorer = false;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
