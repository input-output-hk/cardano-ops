{
  coreNodes = [
    {
      name = "a";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c" "d"];
    }
    {
      name = "b";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "c" "g"];
    }
    {
      name = "c";
      nodeId = 2;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "b"];
    }
    {
      name = "d";
      nodeId = 3;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["e" "f" "a"];
    }
    {
      name = "e";
      nodeId = 4;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["d" "f" "h"];
    }
    {
      name = "f";
      nodeId = 5;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["d" "e"];
    }
    {
      name = "g";
      nodeId = 6;
      org = "IOHK";
      region = "us-east-1";
      producers = ["h" "i" "b"];
    }
    {
      name = "h";
      nodeId = 7;
      org = "IOHK";
      region = "us-east-1";
      producers = ["g" "i" "e"];
    }
    {
      name = "i";
      nodeId = 8;
      org = "IOHK";
      region = "us-east-1";
      producers = ["g" "h"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
