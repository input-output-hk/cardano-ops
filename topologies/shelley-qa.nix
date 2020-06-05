{
  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];

  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "o-a-1";
      region = "eu-central-1";
      producers = [ "o-b-1" "o-c-1" "e-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "o-b-1";
      region = "ap-northeast-1";
      producers = [ "o-c-1" "o-a-1" "e-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "o-c-1";
      region = "ap-southeast-1";
      producers = [ "o-a-1" "o-b-1" "e-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "s-a-1";
      region = "eu-central-1";
      producers = [ "s-b-1" "s-c-1" "s-d-1" "e-a-1" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "s-b-1";
      region = "ap-northeast-1";
      producers = [ "s-c-1" "s-d-1" "s-a-1" "e-b-1" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "s-c-1";
      region = "ap-southeast-1";
      producers = [ "s-d-1" "s-a-1" "s-b-1" "e-c-1" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "s-d-1";
      region = "us-east-1";
      producers = [ "s-a-1" "s-b-1" "s-c-1" "e-d-1" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  relayNodes = [
    # relays
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 101;
      producers = [ "o-a-1" "s-a-1" "e-b-1" "e-c-1" "e-d-1" ];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 102;
      producers = [ "o-b-1" "s-b-1" "e-c-1" "e-a-1" "e-d-1" ];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 103;
      producers = [ "o-c-1" "s-c-1" "e-a-1" "e-b-1" "e-d-1" ];
    }
    {
      name = "e-d-1";
      region = "us-east-1";
      org = "IOHK";
      nodeId = 104;
      producers = [ "s-d-1" "e-a-1" "e-b-1"  ];
    }
  ];
}
