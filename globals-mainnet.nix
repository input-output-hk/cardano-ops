pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "explorer.cardano.org";
  explorerForceSSL = true;
  explorerAliases = [ "explorer.mainnet.cardano.org" "explorer.${pkgs.globals.domain}" ];

  withHighCapacityMonitoring = true;
  withHighCapacityExplorer = true;
  withHighLoadRelays = true;
  withSmash = true;

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

  minMemoryPerInstance = 10;

  # GB per node instance
  nodeDbDiskAllocationSize = 35;

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
      core-node = r5-large;
    };
  };

  relayUpdateArgs = "-m 1500 --maxNodes 12 -s -e devops@iohk.io";
  # Trigger relay topology refresh 12 hours before next epoch
  relayUpdateHoursBeforeNextEpoch = 12;

  dbSyncSnapshotArgs = "-e devops@iohk.io";

  alertChainDensityLow = "85";

  dbSyncSnapshotS3Bucket = "update-cardano-mainnet.iohk.io";
}
