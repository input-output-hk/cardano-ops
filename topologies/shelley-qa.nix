{
  monitoring = {
    services.monitoring-services.publicGrafana = false;
  };

  coreNodes = [
    # backup OBFT centralized nodes
    {
      name = "bft-a-1";
      region = "eu-central-1";
      producers = [ "bft-b-1" "bft-c-1" "rel-a-1" ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "bft-b-1";
      region = "ap-northeast-1";
      producers = [ "bft-c-1" "bft-a-1" "rel-b-1" ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "bft-c-1";
      region = "ap-southeast-1";
      producers = [ "bft-a-1" "bft-b-1" "rel-c-1" ];
      org = "IOHK";
      nodeId = 3;
    }
    # stake pools
    {
      name = "stk-a-1-IOHK1";
      region = "eu-central-1";
      producers = [ "stk-b-1-IOHK2" "stk-c-1-IOHK3" "stk-d-1-IOHK4" "rel-a-1" ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "stk-b-1-IOHK2";
      region = "ap-northeast-1";
      producers = [ "stk-c-1-IOHK3" "stk-d-1-IOHK4" "stk-a-1-IOHK1" "rel-b-1" ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "stk-c-1-IOHK3";
      region = "ap-southeast-1";
      producers = [ "stk-d-1-IOHK4" "stk-a-1-IOHK1" "stk-b-1-IOHK2" "rel-c-1" ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "stk-d-1-IOHK4";
      region = "us-east-1";
      producers = [ "stk-a-1-IOHK1" "stk-b-1-IOHK2" "stk-c-1-IOHK3" "rel-d-1" ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  relayNodes = [
    # relays
    {
      name = "rel-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 101;
      producers = [ "bft-a-1" "stk-a-1-IOHK1" "rel-b-1" "rel-c-1" "rel-d-1" ];
    }
    {
      name = "rel-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 102;
      producers = [ "bft-b-1" "stk-b-1-IOHK2" "rel-c-1" "rel-a-1" "rel-d-1" ];
    }
    {
      name = "rel-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 103;
      producers = [ "bft-c-1" "stk-c-1-IOHK3" "rel-a-1" "rel-b-1" "rel-d-1" ];
    }
    {
      name = "rel-d-1";
      region = "us-east-1";
      org = "IOHK";
      nodeId = 104;
      producers = [ "stk-d-1-IOHK4" "rel-a-1" "rel-b-1"  ];
    }
  ];
}
