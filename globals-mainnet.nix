pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "cardano-explorer";

  environmentName = "mainnet";

  topology = import ./topologies/mainnet.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "mainnet-iohk";
        Emurgo = "mainnet-emurgo";
        CF = "mainnet-cf";
        dns = "mainnet-iohk";
      };
    };
  };
}
