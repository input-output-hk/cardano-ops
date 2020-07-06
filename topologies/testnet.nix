{
  legacyCoreNodes = [];

  legacyRelayNodes = [
    {
      name = "r-a-1";
      region = "eu-central-1";
      staticRoutes = [
        ["c-d-1" "c-a-1"] ["b-a-1" "c-a-1"] ["r-a-2" "r-d-1"]
        [ "b-a-1" "b-b-1"] ["b-c-1" "b-d-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-2";
      region = "eu-central-1";
      staticRoutes = [
        ["c-a-1" "c-d-1"] ["b-a-1" "c-d-1"] ["r-d-1" "r-a-1"]
        [ "b-a-1" "b-d-1"] ["b-c-1" "b-b-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        ["c-b-1" "b-d-1"] ["r-d-1" "r-a-2"] ["r-b-2" "r-c-1"]
        [ "b-b-1" "b-a-1"] ["b-c-1" "b-d-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        ["c-b-1" "b-a-1"] ["r-b-1" "r-a-1"] ["r-c-2" "r-c-1"]
        [ "b-b-1" "b-d-1"] ["b-c-1" "b-a-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        ["c-c-1" "c-c-2"] ["r-a-2" "r-a-1"] ["r-c-2" "r-a-1"]
        [ "b-c-1" "b-a-1"] ["b-b-1" "b-d-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        ["c-c-2" "c-c-1"] ["r-b-2" "r-b-1"] ["r-c-1" "r-a-1"]
        [ "b-c-1" "b-d-1"] ["b-b-1" "b-a-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-d-1";
      region = "us-east-2";
      staticRoutes = [
        ["c-d-1" "b-a-1"] ["c-a-1" "b-a-1"] ["r-a-1" "r-a-2"] ["r-b-1" "r-b-2"]
        [ "b-d-1" "b-b-1"] ["b-a-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "p-d-1";
      region = "us-east-2";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-d-1"
          "r-a-2"]
        [ "r-b-2"
          "r-c-2"
          "r-c-1"
          "r-a-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-d-2";
      region = "us-west-2";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-d-1"
          "r-c-2"]
        [ "r-b-2"
          "r-a-1"
          "r-a-2"
          "r-c-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-d-3";
      region = "ca-central-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-d-1"
          "r-c-2"]
        [ "r-b-2"
          "r-c-1"
          "r-a-2"
          "r-a-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-b-1";
      region = "ap-northeast-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-a-2"
          "r-c-1"]
        [ "r-b-2"
          "r-c-2"
          "r-a-1"
          "r-d-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-b-2";
      region = "ap-south-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-c-1"
          "r-a-1"]
        [ "r-b-2"
          "r-d-1"
          "r-a-2"
          "r-c-2"]
      ];
      org = "IOHK";
    }
    {
      name = "p-c-1";
      region = "ap-southeast-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-c-2"
          "r-d-1"]
        [ "r-b-2"
          "r-a-2"
          "r-a-1"
          "r-c-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-c-2";
      region = "ap-southeast-2";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-d-1"
          "r-c-2"]
        [ "r-b-2"
          "r-c-1"
          "r-a-2"
          "r-a-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-a-1";
      region = "eu-central-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-d-1"
          "r-c-1"]
        [ "r-b-2"
          "r-c-2"
          "r-a-2"
          "r-a-1"]
      ];
      org = "IOHK";
    }
    {
      name = "p-a-2";
      region = "eu-west-1";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-a-1"
          "r-c-1"]
        [ "r-b-2"
          "r-c-2"
          "r-d-1"
          "r-a-2"]
      ];
      org = "IOHK";
    }
    {
      name = "p-a-3";
      region = "eu-west-2";
      dynamicSubscribe = [
        [ "r-b-1"
          "r-c-1"
          "r-c-2"]
        [ "r-b-2"
          "r-d-1"
          "r-a-1"
          "r-a-2"]
      ];
      org = "IOHK";
    }
  ];

  byronProxies = [
    {
      name = "b-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 15;
      producers = [ "c-a-2" "b-b-1" "b-c-1" "b-d-1" "e-a-1" "e-a-2" ];
      staticRoutes = [
        [ "r-a-1" "r-d-1" "r-c-2" ]
        [ "r-a-2" "r-c-1" "r-b-2" ]
      ];
    }
    {
      name = "b-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 16;
      producers = [ "c-b-2" "b-b-1" "b-c-1" "b-d-1" "e-b-1" "e-b-2" ];
      staticRoutes = [
        [ "r-b-1" "r-d-1" "r-c-1" ]
        [ "r-b-2" "r-c-2" "r-a-1" ]
      ];
    }
    {
      name = "b-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 17;
      producers = [ "c-a-2" "b-a-1" "b-b-1" "b-d-1" "e-c-1" "e-c-2" ];
      staticRoutes = [
        [ "r-c-1" "r-d-1" "r-b-2" ]
        [ "r-c-2" "r-b-1" "r-a-2" ]
      ];
    }
    {
      name = "b-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 18;
      producers = [ "c-b-2" "b-a-1" "b-b-1" "b-c-1" "e-d-1" "e-d-2" ];
      staticRoutes = [
        [ "r-d-1" "r-a-1" "r-b-1" "r-c-1" ]
      ];
    }
  ];

  coreNodes = [
    {
      name = "c-a-1";
      region = "eu-central-1";
      producers = [
        "c-a-2"
        "c-b-1" "c-c-1" "c-d-1"
        "e-a-1" "e-a-2"
        "e-b-1"
        "b-a-1"
      ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = [
        "c-a-1"
        "c-b-2" "c-c-2"
        "e-a-1" "e-a-2"
        "e-c-1" "e-d-1"
        "b-a-1"
      ];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      producers = [
        "c-b-2"
        "c-a-1" "c-c-1" "c-d-1"
        "e-b-1" "e-b-2"
        "e-a-1"
        "b-b-1"
      ];
      org = "IOHK";
      nodeId = 3;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = [
        "c-b-1"
        "c-a-2" "c-c-2"
        "e-b-1" "e-b-2"
        "e-c-2" "e-d-2"
        "b-b-1"
      ];
      org = "IOHK";
      nodeId = 4;
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      producers = [
        "c-c-2"
        "c-a-1" "c-b-1" "c-d-1"
        "e-c-1" "e-c-2"
        "e-a-1"
        "b-c-1"
      ];
      org = "IOHK";
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      producers = [
        "c-c-1"
        "c-a-2" "c-b-2"
        "e-c-1" "e-c-2"
        "e-b-2" "e-d-2"
        "b-c-1"
      ];
      org = "IOHK";
      nodeId = 6;
    }
    {
      name = "c-d-1";
      region = "us-east-2";
      producers = [
        "c-a-1" "c-b-1" "c-c-1"
        "e-d-1" "e-d-2"
        "e-a-1" "e-b-1" "e-c-1"
        "b-d-1"
      ];
      org = "IOHK";
      nodeId = 7;
    }
   ];

  relayNodes = [
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = ["b-a-1" "c-a-2" "e-a-2" "e-b-1" "e-c-1" "e-d-1"];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = ["b-b-1" "c-b-2" "e-b-2" "e-a-1" "e-d-1" "e-c-1"];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 10;
      producers = ["b-c-1" "c-c-2" "e-c-2" "e-d-1" "e-a-1" "e-b-1"];
    }
    {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 11;
      producers = ["b-d-1" "c-d-1" "e-d-2" "e-c-1" "e-a-1" "e-b-1"];
    }
    {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 12;
      producers = ["b-a-1" "c-a-1" "e-a-1" "e-b-2" "e-c-2" "e-d-2"];
    }
    {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 13;
      producers = ["b-b-1" "c-b-1" "e-b-1" "e-a-2" "e-c-2" "e-d-2"];
    }
    {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 14;
      producers = ["b-c-1" "c-c-1" "e-c-1" "e-a-2" "e-b-2" "e-d-2"];
    }
    {
      name = "e-d-2";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 15;
      producers = ["b-d-1" "c-d-1" "e-d-1" "e-a-2" "e-b-2" "e-c-2"];
    }
  ];
}
