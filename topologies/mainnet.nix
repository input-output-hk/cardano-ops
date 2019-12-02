{
  legacyCoreNodes = [
   {
      name = "c-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-2" "c-d-1" ]
        [ "c-c-2" "c-c-1" ]
        [ "r-a-1" "r-a-2" ]
        [ "b-a-1" "b-b-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-d-1" "c-a-1" ]
        [ "c-b-1" "c-d-1" ]
        [ "c-a-1" "c-b-1" ]
        [ "r-a-2" "r-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "r-b-2" ]
        [ "c-c-1" "c-c-2" ]
        [ "c-a-1" "c-d-1" ]
        [ "r-b-1" "r-b-2" ]
        [ "b-b-1" "b-a-1" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-a-2" "c-d-1" ]
        [ "c-b-1" "r-b-1" ]
        [ "r-b-2" "r-b-1" ]
        [ "b-b-1" "b-c-1" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-d-1" "c-a-1" ]
        [ "c-c-2" "r-c-1" ]
        [ "r-c-1" "r-c-2" ]
        [ "b-c-1" "b-a-1" ]
      ];
      org = "CF";
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-b-2" "c-b-1" ]
        [ "c-c-1" "r-c-1" ]
        [ "r-c-2" "r-c-1" ]
        [ "b-c-1" "b-b-1" ]
      ];
      org = "CF";
    }
    {
      name = "c-d-1";
      region = "us-east-2";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "c-b-1" "c-b-2" ]
        [ "c-c-1" "c-c-2" ]
        [ "r-d-1" "r-a-1" ]
        [ "b-b-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
  ];

  legacyRelayNodes = [
    {
      name = "r-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-d-1" "c-a-1" ]
        [ "c-a-2" "c-a-1" ]
        [ "r-a-2" "r-d-1" ]
        [ "b-a-1" "b-b-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-d-1" ]
        [ "c-a-2" "c-d-1" ]
        [ "r-d-1" "r-a-1" ]
        [ "b-a-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-d-1";
      region = "us-east-2";
      staticRoutes = [
        [ "c-d-1" "c-a-2" ]
        [ "c-a-1" "c-a-2" ]
        [ "r-a-1" "r-a-2" ]
        [ "r-b-1" "r-b-2" ]
        [ "b-c-1" "b-b-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-1" "c-b-2" ]
        [ "r-d-1" "r-a-2" ]
        [ "r-b-2" "r-c-1" ]
        [ "b-b-1" "b-a-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "c-b-1" ]
        [ "r-b-1" "r-a-1" ]
        [ "r-c-2" "r-c-1" ]
        [ "b-b-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-1" "c-c-2" ]
        [ "r-a-2" "r-a-1" ]
        [ "r-c-2" "r-a-1" ]
        [ "b-c-1" "b-a-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-2" "c-c-1" ]
        [ "r-b-2" "r-b-1" ]
        [ "r-c-1" "r-a-1" ]
        [ "b-c-1" "b-b-1" ]
      ];
      org = "IOHK";
    }

    {
      name = "p-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-a-2"]
        [ "r-b-2" "r-c-2" "r-c-1" "r-a-1" ]
      ];
    }
    {
      name = "p-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-2"]
        [ "r-b-2" "r-a-1" "r-a-2" "r-c-1" ]
      ];
    }
    {
      name = "p-b-3";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-2"]
        [ "r-b-2" "r-c-1" "r-a-2" "r-a-1" ]
      ];
    }
    {
      name = "p-b-4";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-2" "r-c-1"]
        [ "r-b-2" "r-c-2" "r-a-1" "r-d-1" ]
      ];
    }
    {
      name = "p-b-5";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-1" "r-a-1"]
        [ "r-b-2" "r-d-1" "r-a-2" "r-c-2" ]
      ];
    }
    {
      name = "p-b-6";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-2" "r-d-1"]
        [ "r-b-2" "r-a-2" "r-a-1" "r-c-1" ]
      ];
    }
    {
      name = "p-b-7";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-2"]
        [ "r-b-2" "r-c-1" "r-a-2" "r-a-1" ]
      ];
    }
    {
      name = "p-b-8";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-1"]
        [ "r-b-2" "r-c-2" "r-a-2" "r-a-1" ]
      ];
    }
    {
      name = "p-b-9";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-1"]
        [ "r-b-2" "r-c-2" "r-d-1" "r-a-2" ]
      ];
    }
    {
      name = "p-b-10";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-1" "r-c-2"]
        [ "r-b-2" "r-d-1" "r-a-1" "r-a-2" ]
      ];
    }
    {
      name = "p-b-11";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-1"]
        [ "r-b-2" "r-a-2" "r-c-2" "r-d-1" ]
      ];
    }
    {
      name = "p-b-12";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-1" "r-a-2"]
        [ "r-b-2" "r-a-1" "r-c-2" "r-d-1" ]
      ];
    }
    {
      name = "p-b-13";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-1"]
        [ "r-b-2" "r-d-1" "r-c-2" "r-a-2" ]
      ];
    }
    {
      name = "p-b-14";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-2"]
        [ "r-b-2" "r-a-2" "r-d-1" "r-c-1" ]
      ];
    }
    {
      name = "p-b-15";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-1"]
        [ "r-b-2" "r-a-2" "r-a-1" "r-c-2" ]
      ];
    }
    {
      name = "p-b-16";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-1" "r-d-1"]
        [ "r-b-2" "r-a-1" "r-c-2" "r-a-2" ]
      ];
    }
    {
      name = "p-b-17";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-c-1"]
        [ "r-b-2" "r-a-2" "r-a-1" "r-d-1" ]
      ];
    }
    {
      name = "p-b-18";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-c-2" "r-d-1"]
        [ "r-b-2" "r-c-1" "r-a-1" "r-a-2" ]
      ];
    }
    {
      name = "p-b-19";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-1"]
        [ "r-b-2" "r-a-2" "r-c-2" "r-d-1" ]
      ];
    }
    {
      name = "p-b-20";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-a-1" "r-c-1"]
        [ "r-b-2" "r-a-2" "r-d-1" "r-c-2" ]
      ];
    }
    {
      name = "p-b-21";
      region = "ap-northeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-b-1" "r-d-1" "r-a-2"]
        [ "r-b-2" "r-c-1" "r-a-1" "r-c-2" ]
      ];
    }
    {
      name = "p-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-b-2"]
        [ "r-c-2" "r-a-1" "r-b-1" "r-d-1" ]
      ];
    }
    {
      name = "p-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-2" "r-b-1"]
        [ "r-c-2" "r-a-1" "r-d-1" "r-a-2" ]
      ];
    }
    {
      name = "p-c-3";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-d-1" "r-a-1"]
        [ "r-c-2" "r-a-2" "r-b-1" "r-b-2" ]
      ];
    }
    {
      name = "p-c-4";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-2" "r-a-2"]
        [ "r-c-2" "r-d-1" "r-a-1" "r-b-1" ]
      ];
    }
    {
      name = "p-c-5";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-2" "r-a-1"]
        [ "r-c-2" "r-a-2" "r-d-1" "r-b-1" ]
      ];
    }
    {
      name = "p-c-6";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-d-1" "r-a-1"]
        [ "r-c-2" "r-b-1" "r-b-2" "r-a-2" ]
      ];
    }
    {
      name = "p-c-7";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-d-1"]
        [ "r-c-2" "r-b-2" "r-a-1" "r-b-1" ]
      ];
    }
    {
      name = "p-c-8";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-1" "r-b-1"]
        [ "r-c-2" "r-d-1" "r-b-2" "r-a-2" ]
      ];
    }
    {
      name = "p-c-9";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-b-2"]
        [ "r-c-2" "r-d-1" "r-a-1" "r-b-1" ]
      ];
    }
    {
      name = "p-c-10";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-1" "r-d-1"]
        [ "r-c-2" "r-b-2" "r-b-1" "r-a-2" ]
      ];
    }
    {
      name = "p-c-11";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-d-1" "r-b-2"]
        [ "r-c-2" "r-a-1" "r-b-1" "r-a-2" ]
      ];
    }
    {
      name = "p-c-12";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-1" "r-d-1"]
        [ "r-c-2" "r-b-2" "r-a-2" "r-b-1" ]
      ];
    }
    {
      name = "p-c-13";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-b-2"]
        [ "r-c-2" "r-d-1" "r-b-1" "r-a-1" ]
      ];
    }
    {
      name = "p-c-14";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-1" "r-a-1"]
        [ "r-c-2" "r-a-2" "r-d-1" "r-b-2" ]
      ];
    }
    {
      name = "p-c-15";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-b-2"]
        [ "r-c-2" "r-d-1" "r-b-1" "r-a-1" ]
      ];
    }
    {
      name = "p-c-16";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-1" "r-a-1"]
        [ "r-c-2" "r-a-2" "r-d-1" "r-b-2" ]
      ];
    }
    {
      name = "p-c-17";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-d-1" "r-b-2"]
        [ "r-c-2" "r-b-1" "r-a-2" "r-a-1" ]
      ];
    }
    {
      name = "p-c-18";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-2" "r-a-1"]
        [ "r-c-2" "r-d-1" "r-a-2" "r-b-1" ]
      ];
    }
    {
      name = "p-c-19";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-a-2" "r-a-1"]
        [ "r-c-2" "r-b-2" "r-b-1" "r-d-1" ]
      ];
    }
    {
      name = "p-c-20";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-1" "r-d-1"]
        [ "r-c-2" "r-a-1" "r-b-2" "r-a-2" ]
      ];
    }
    {
      name = "p-c-21";
      region = "ap-southeast-1";
      org = "IOHK";
      dynamicSubscribe = [
        [ "r-c-1" "r-b-2" "r-a-1"]
        [ "r-c-2" "r-d-1" "r-a-2" "r-b-1" ]
      ];
    }
  ];

  byronProxies = [
    {
      name = "b-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 15;
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
      staticRoutes = [
        [ "r-c-1" "r-d-1" "r-b-2" ]
        [ "r-c-2" "r-b-1" "r-a-2" ]
      ];
    }
  ];

  coreNodes = [ ];

  relayNodes = [
    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = ["b-a-1" "e-b-1" "e-c-1"];
    }
    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = ["b-b-1" "e-a-1" "e-c-1"];
    }
    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 11;
      producers = ["b-c-1" "e-a-1" "e-b-1"];
    }
    {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 12;
      producers = ["e-a-1" "e-b-1"];
    }
  ];
}
