pkgs: {

  deploymentName = "node-tests";

  # Override the global-defaults.nix
  withExplorer = false;
  withLegacyExplorer = false;

  # This will need to adjust dynamically per node
  # need to test against multiple environments;
  # also affects the need to support multiple
  # environmentConfig attrs
  environmentName = "staging";

  topology = import ./topologies/node-tests.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "dev-deployer";
        dns = "dev-deployer";
      };
    };
  };
}
