pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "explorer.cardano.org";
  explorerForceSSL = true;
  explorerAliases = [ "explorer.mainnet.cardano.org" "explorer.${pkgs.globals.domain}" ];
  explorerIogAliases = [ "beta.explorer.iohk.io" ];

  withCardanoDBExtended = true;
  withHighCapacityMonitoring = true;
  withHighCapacityExplorer = true;
  withHighLoadRelays = true;
  withSmash = true;
  withExplorerIog = true;

  withMetadata = true;
  metadataHostName = "tokens.cardano.org";

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
    instances = with pkgs.iohk-ops-lib.physical.aws; {
      relay-node = t3-xlarge;
    };
  };

  relayUpdateArgs = "-m 1500 --maxNodes 12 -s -e devops@iohk.io";
  # Trigger relay topology refresh 12 hours before next epoch
  relayUpdateHoursBeforeNextEpoch = 12;

  alertChainDensityLow = "85";
}
