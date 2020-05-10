{
  coreNodes = [
    {
      name = "a";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c" "d" "e" "f"];
    }
    {
      name = "b";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "c" "d" "e" "f"];
    }
    {
      name = "c";
      nodeId = 2;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "d" "e" "f"];
    }
    {
      name = "d";
      nodeId = 3;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "c" "e" "f"];
    }
    {
      name = "e";
      nodeId = 4;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "f"];
    }
    {
      name = "f";
      nodeId = 5;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "e"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
