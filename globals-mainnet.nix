pkgs: {

  deploymentName = "mainnet";

  dnsZone = "${pkgs.globals.domain}";

  domain = "cardano-mainnet.iohk.io";

  explorerHostName = "explorer.cardano.org";
  explorerForceSSL = true;
  explorerAliases = [ "explorer.mainnet.cardano.org" "explorer.${pkgs.globals.domain}" ];
  explorerBackends = {
    a = pkgs.globals.explorer13;
    b = pkgs.globals.explorer13;
    c = pkgs.globals.explorer13;
  };

  explorerActiveBackends = [
    "a"
    "b"
    "c"
  ];

  withHighCapacityMonitoring = true;
  withHighCapacityExplorer = true;
  withHighLoadRelays = true;
  withSmash = true;
  withSnapshots = true;

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

  minMemoryPerInstance = 15;

  # GB per node instance
  nodeDbDiskAllocationSize = 140;

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

  relayUpdateArgs = "-m 3100 --maxNodes 11 -s -e devops@iohk.io";
  # Trigger relay topology refresh 12 hours before next epoch
  relayUpdateHoursBeforeNextEpoch = 12;

  snapshotStatesArgs = "-e devops@iohk.io";

  alertChainDensityLow = "85";

  snapshotStatesS3Bucket = "update-cardano-mainnet.iohk.io";

  smashDelistedPools = [
    "413b0496a93ff4ef5d7436828e9764d37778d74d60a62451cfbed057"
    "ce2e5bbae0caa514670d63cfdad3123a5d32cf7c37df87add5a0f75f"
    "2b830258888a09e846b63474c642ad4e18aecd08dafb1f2a4d653e80"
    "027a08f49ad5ece08e3a1575fb9cd8e8d7cf3b7815807a20b1a715f1"
    "4eb1fac09251f8af19ad6b7e06b71cbad09dbe896b481e4670fe565d"
    "bf44d3187cbdd8874dca1f714a6107beea642753228490bc02c8e038"
    "00429f0a3e8c48d644a9b45babd09b86c367efe745a35b31f10e859f"
    "8bc067247b8a85500d40d7bb78afd4de6a5fed2cfcc82c9b9c2fa8a2"
    "e7e18f2050fa307fc9405f1d517760e894f8fbdf41a9b1b280571b38"
    "27f4e3c309659f824026893b811dd6e70332881867cb2cba4974191c"
    "c73186434c6fc6676bd67304d34518fc6fd7d5eaddaf78641b1e7dcf"
    "2064da38531dad327135edd98003032cefa059c4c8c50c2b0440c63d"
    "d9df218f8099261e019bdd304b9a40228070ce61272af835ea13d161"
    "d7d56e1703630780176cf944a77b7829b4ba97888fa9a32468011985"
    "82e5cb6e4b443c36b087e6218a5629291585d35083ce2cb625506e1f"
    "0e76c44520b9d7f2e211eccd82de49350288368802c7aaa72a13c3fa"
    "d471e981d54a7f60496f9239d2d706db7a71df8517025f478c112e3e"
    "f537b3a5ac2ecdc854a535a15f7732632375a0bf2af17dccbe5b422d"
    "033fa1cdc17193fa3d549e795591999621e749fd7ef48f7380468d14"
    "47e694d52e08b1a65636c07911e7dd4282afbc555bccfda22c3c52f0"
    "8e2f5c1e8ca0f70f00a9b17de911af716678f9e2b653728f356c7ef6"
    "57ff19460990690bc6a2edfae4dbaaa56ce2fedbcec9b37334d33a1c"
    "2d6765748cc86efe862f5abeb0c0271f91d368d300123ecedc078ef2"
    "58b5c7e14957e2f32e988440b0e353ff939dc1597f5c8a4674b53d47"
    "93932f14ee3117ba4ac119f9f7722f1143d02760cd5328955804ea36"
    "40efc97d08315ff9be5898f24af5b8b120669b43027662c3499dd785"
    "ae8dbaaa4ebfdba74618653a619d28d58232638ac83ccb5d66edee36"
    "78e07590b2a28ca0e90602fb9319e11770b516ec34387c663ebda287"
    "718268428577002a004ef37ef62933c21d82e41cd7816da381716291"
  ];
}
