pkgs: {

  deploymentName = "wavegp";

  environmentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";
  domain = "wavelovelace.com";
  relaysNew = "relays.${pkgs.globals.domain}";

  withExplorer = false;

  topology = import ./topologies/wavegp.nix pkgs;

  ec2 = {
    credentials = {
      accessKeyIds = {
        WAVE = "wavegp";
        dns = "wavegp";
      };
    };
  };

  alertChainDensityLow = "85";
  alertTcpHigh = "220";
  alertTcpCrit = "250";


  # 20GB per node instance
  nodeDbDiskAllocationSize = 20;
}
