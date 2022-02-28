pkgs: {

  deploymentName = "testnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-testnet.iohkdev.io";

  withSubmitApi = true;
  withFaucet = true;
  withSmash = true;
  withMetadata = true;
  withHighLoadRelays = true;
  withSnapshots = true;

  faucetHostname = "faucet";

  initialPythonExplorerDBSyncDone = true;

  environmentName = "testnet";

  topology = import ./topologies/testnet.nix pkgs;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "default";
      };
    };
    instances = with pkgs.iohk-ops-lib.physical.aws; {
      metadata = t3a-xlarge;
      core-node = r5-large;
    };
  };

  relayUpdateArgs = "-m 50 -s -e devops@iohk.io";
  # Trigger relay topology refresh 12 hours before next epoch
  relayUpdateHoursBeforeNextEpoch = 12;
  dbSyncSnapshotPeriod = "15d";
  dbSyncSnapshotArgs = "-e devops@iohk.io";
  dbSyncSnapshotS3Bucket = "updates-cardano-testnet";

  alertChainDensityLow = "50";

  metadataVarnishTtl = 15;
}
