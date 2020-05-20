{
  coreNodes = [
    {
      name = "node-0";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["node-1" "node-2" "node-3" "node-4" "node-5"];
    }
    {
      name = "node-1";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["node-0" "node-2" "node-3" "node-4" "node-5"];
    }
    {
      name = "node-2";
      nodeId = 2;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["node-0" "node-1" "node-3" "node-4" "node-5"];
    }
    {
      name = "node-3";
      nodeId = 3;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["node-0" "node-1" "node-2" "node-4" "node-5"];
    }
    {
      name = "node-4";
      nodeId = 4;
      org = "IOHK";
      region = "us-east-1";
      producers = ["node-0" "node-1" "node-2" "node-3" "node-5"];
    }
    {
      name = "node-5";
      nodeId = 5;
      org = "IOHK";
      region = "us-east-1";
      producers = ["node-0" "node-1" "node-2" "node-3" "node-4"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
