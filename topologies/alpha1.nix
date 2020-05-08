{
  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];

  coreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [ "c-b-1" "c-c-1" "e-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [ "c-c-1" "c-a-1" "e-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [ "c-a-1" "c-b-1" "e-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
  ];

  relayNodes = [
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = [ "c-a-1" "e-b-1" "e-c-1" ];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = [ "c-b-1" "e-c-1" "e-a-1" ];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 10;
      producers = [ "c-c-1" "e-a-1" "e-b-1"  ];
    }
  ];
}
