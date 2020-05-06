{
  coreNodes = [
    {
      name = "a";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c"];
    }
    {
      name = "b";
      nodeId = 1;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["c" "a"];
    }
    {
      name = "c";
      nodeId = 2;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
