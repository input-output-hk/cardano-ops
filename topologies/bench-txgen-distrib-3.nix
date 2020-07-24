{
  coreNodes = [
    {
      name = "node-0";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["node-1" "node-2"];
      stakePool = true;
    }
    {
      name = "node-1";
      nodeId = 1;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["node-2" "node-0"];
      stakePool = true;
    }
    {
      name = "node-2";
      nodeId = 2;
      org = "IOHK";
      region = "us-east-1";
      producers = ["node-0" "node-1"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
