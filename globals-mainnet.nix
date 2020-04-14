pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "explorer";
  explorerForceSSL = true;
  explorerAliases = [ "explorer.mainnet.cardano.org" "explorer.cardano.org" ];

  withHighCapacityMonitoring = true;
  withHighLoadRelays = true;

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
