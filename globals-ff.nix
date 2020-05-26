pkgs: {

  deploymentName = "ff";

  topology = import ./topologies/ff.nix pkgs;

  withExplorer = false;
  withLegacyExplorer = false;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };
}
