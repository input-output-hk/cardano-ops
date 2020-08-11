pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "explorer";
  explorerForceSSL = true;
  explorerAliases = [ "explorer.mainnet.cardano.org" "explorer.cardano.org" ];

  withCardanoDBExtended = true;
  withHighCapacityMonitoring = true;
  withHighCapacityExplorer = true;
  withHighLoadRelays = true;

  initialPythonExplorerDBSyncDone = true;

  environmentName = "mainnet";

  topology = import ./topologies/mainnet.nix pkgs;

  maxRulesPerSg = {
    IOHK = 61;
    Emurgo = 36;
    CF = 36;
  };

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

  alertChainDensityLow = "98";
  alertTcpHigh = "250";
  alertTcpCrit = "300";
}
