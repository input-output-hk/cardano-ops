{
  legacyCoreNodes = [
   {
      name = "c-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "b-a-2" "c-d-1" ]
        [ "c-c-2" "c-c-1" ]
        [ "r-a-1" "r-a-2" ]
        [ "b-a-1" "b-b-1" ]
      ];
      org = "IOHK";
      nodeId = 1;
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "b-d-1" "r-b-2" ]
        [ "c-c-1" "c-c-2" ]
        [ "c-a-1" "c-d-1" ]
        [ "r-b-1" "r-b-2" ]
        [ "b-b-1" "b-a-1" ]
      ];
      org = "Emurgo";
      nodeId = 3;
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
      nodeId = 5;
    }
    {
      name = "c-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "b-b-1" "c-b-1" ]
        [ "c-c-1" "r-c-1" ]
        [ "r-c-2" "r-c-1" ]
        [ "b-c-1" "b-b-1" ]
      ];
      org = "CF";
      nodeId = 6;
    }
    {
      name = "c-d-1";
      region = "us-east-2";
      staticRoutes = [
        [ "c-a-1" "b-a-1" ]
        [ "c-b-1" "b-b-1" ]
        [ "c-c-1" "c-c-2" ]
        [ "r-d-1" "r-a-1" ]
        [ "b-d-1" "b-b-1" ]
      ];
      org = "IOHK";
      nodeId = 7;
    }
  ];

  legacyRelayNodes = [
    {
      name = "r-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-d-1" "c-a-1" ]
        [ "b-c-1" "c-a-1" ]
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
        [ "b-b-1" "c-d-1" ]
        [ "r-d-1" "r-a-1" ]
        [ "b-a-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-d-1";
      region = "us-east-2";
      staticRoutes = [
        [ "c-d-1" "b-a-1" ]
        [ "c-a-1" "b-a-1" ]
        [ "r-a-1" "r-a-2" ]
        [ "r-b-1" "r-b-2" ]
        [ "b-d-1" "b-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-1" "b-b-1" ]
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
        [ "b-a-1" "c-b-1" ]
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
      producers = [ "c-a-2" "b-b-1" "b-c-1" "b-d-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" ];
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
      producers = [ "c-b-2" "b-a-1" "b-c-1" "b-d-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" ];
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
      producers = [ "c-a-2" "b-a-1" "b-b-1" "b-d-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" ];
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
      producers = [ "c-b-2" "b-a-1" "b-b-1" "b-c-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" ];
      staticRoutes = [
        [ "r-d-1" "r-a-2" "r-b-2" "r-c-2" ]
      ];
    }
  ];

  coreNodes = [
    {
      name = "c-a-2";
      region = "eu-central-1";
      producers = ["b-a-1" "c-b-2" "b-d-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-c-2" "e-b-2" "e-d-2"];
      org = "IOHK";
      nodeId = 2;
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      producers = ["b-b-1" "c-a-2" "b-c-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-a-4" "e-c-4" "e-d-4"];
      org = "Emurgo";
      nodeId = 4;
    }
   ];

  relayNodes = [

    # e-a-1 - 5 edge nodes

    {
      name = "e-a-1";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 8;
      producers = [ "b-a-1" "c-a-2" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-b-1" "e-c-1" "e-d-1" ];
    }
    {
      name = "e-a-2";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 19;
      producers = [ "b-a-1" "c-a-2" "e-a-1" "e-a-3" "e-a-4" "e-a-5" "e-b-2" "e-c-2" "e-d-2" ];
    }
    {
      name = "e-a-3";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 20;
      producers = [ "b-a-1" "c-a-2" "e-a-1" "e-a-2" "e-a-4" "e-a-5" "e-b-3" "e-c-3" "e-d-3" ];
    }
    {
      name = "e-a-4";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 21;
      producers = [ "b-a-1" "c-a-2" "e-a-1" "e-a-2" "e-a-3" "e-a-5" "e-b-4" "e-c-4" "e-d-4" ];
    }
    {
      name = "e-a-5";
      region = "eu-central-1";
      org = "IOHK";
      nodeId = 22;
      producers = [ "b-a-1" "c-a-2" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-b-5" "e-c-5" "e-d-5" ];
    }

    # e-a-6 - 10 edge nodes

    #{
    #  name = "e-a-6";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 101;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-6" "e-c-6" "e-d-6" ];
    #}
    #{
    #  name = "e-a-7";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 102;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-7" "e-c-7" "e-d-7" ];
    #}
    #{
    #  name = "e-a-8";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 103;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-8" "e-c-8" "e-d-8" ];
    #}
    #{
    #  name = "e-a-9";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 104;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-9" "e-c-9" "e-d-9" ];
    #}
    #{
    #  name = "e-a-10";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 105;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-10" "e-c-10" "e-d-10" ];
    #}

    ## e-a-11 - 15 edge nodes

    #{
    #  name = "e-a-11";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 106;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-11" "e-c-11" "e-d-11" ];
    #}
    #{
    #  name = "e-a-12";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 107;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-12" "e-c-12" "e-d-12" ];
    #}
    #{
    #  name = "e-a-13";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 108;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-13" "e-c-13" "e-d-13" ];
    #}
    #{
    #  name = "e-a-14";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 109;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-14" "e-c-14" "e-d-14" ];
    #}
    #{
    #  name = "e-a-15";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 110;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-15" "e-c-15" "e-d-15" ];
    #}

    ## e-a-16 - 20 edge nodes

    #{
    #  name = "e-a-16";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 111;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-16" "e-c-16" "e-d-16" ];
    #}
    #{
    #  name = "e-a-17";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 112;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-17" "e-c-17" "e-d-17" ];
    #}
    #{
    #  name = "e-a-18";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 113;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-18" "e-c-18" "e-d-18" ];
    #}
    #{
    #  name = "e-a-19";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 114;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-19" "e-c-19" "e-d-19" ];
    #}
    #{
    #  name = "e-a-20";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 115;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-20" "e-c-20" "e-d-20" ];
    #}

    ## e-a-21 - 25 edge nodes

    #{
    #  name = "e-a-21";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 116;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-22" "e-a-23" "e-a-24" "e-a-25" "e-b-21" "e-c-21" "e-d-21" ];
    #}
    #{
    #  name = "e-a-22";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 117;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-23" "e-a-24" "e-a-25" "e-b-22" "e-c-22" "e-d-22" ];
    #}
    #{
    #  name = "e-a-23";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 118;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-24" "e-a-25" "e-b-23" "e-c-23" "e-d-23" ];
    #}
    #{
    #  name = "e-a-24";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 119;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-25" "e-b-24" "e-c-24" "e-d-24" ];
    #}
    #{
    #  name = "e-a-25";
    #  region = "eu-central-1";
    #  org = "IOHK";
    #  nodeId = 120;
    #  producers = [ "b-a-1" "e-a-1" "e-a-2" "e-a-3" "e-a-4" "e-a-5" "e-a-6" "e-a-7" "e-a-8" "e-a-9" "e-a-10" "e-a-11" "e-a-12" "e-a-13" "e-a-14" "e-a-15" "e-a-16" "e-a-17" "e-a-18" "e-a-19" "e-a-20" "e-a-21" "e-a-22" "e-a-23" "e-a-24" "e-b-25" "e-c-25" "e-d-25" ];
    #}

    # e-b-1 - 5 edge nodes

    {
      name = "e-b-1";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 9;
      producers = [ "b-b-1" "c-b-2" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-a-1" "e-c-1" "e-d-1" ];
    }
    {
      name = "e-b-2";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 23;
      producers = [ "b-b-1" "c-b-2" "e-b-1" "e-b-3" "e-b-4" "e-b-5" "e-a-2" "e-c-2" "e-d-2" ];
    }
    {
      name = "e-b-3";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 24;
      producers = [ "b-b-1" "c-b-2" "e-b-1" "e-b-2" "e-b-4" "e-b-5" "e-a-3" "e-c-3" "e-d-3" ];
    }
    {
      name = "e-b-4";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 25;
      producers = [ "b-b-1" "c-b-2" "e-b-1" "e-b-2" "e-b-3" "e-b-5" "e-a-4" "e-c-4" "e-d-4" ];
    }
    {
      name = "e-b-5";
      region = "ap-northeast-1";
      org = "IOHK";
      nodeId = 26;
      producers = [ "b-b-1" "c-b-2" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-a-5" "e-c-5" "e-d-5" ];
    }

    # e-b-6 - 10 edge nodes

    #{
    #  name = "e-b-6";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 121;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-6" "e-c-6" "e-d-6" ];
    #}
    #{
    #  name = "e-b-7";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 122;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-7" "e-c-7" "e-d-7" ];
    #}
    #{
    #  name = "e-b-8";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 123;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-8" "e-c-8" "e-d-8" ];
    #}
    #{
    #  name = "e-b-9";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 124;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-9" "e-c-9" "e-d-9" ];
    #}
    #{
    #  name = "e-b-10";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 125;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-10" "e-c-10" "e-d-10" ];
    #}

    ## e-b-11 - 15 edge nodes

    #{
    #  name = "e-b-11";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 126;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-11" "e-c-11" "e-d-11" ];
    #}
    #{
    #  name = "e-b-12";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 127;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-12" "e-c-12" "e-d-12" ];
    #}
    #{
    #  name = "e-b-13";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 128;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-13" "e-c-13" "e-d-13" ];
    #}
    #{
    #  name = "e-b-14";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 129;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-14" "e-c-14" "e-d-14" ];
    #}
    #{
    #  name = "e-b-15";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 130;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-15" "e-c-15" "e-d-15" ];
    #}

    ## e-b-16 - 20 edge nodes

    #{
    #  name = "e-b-16";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 131;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-16" "e-c-16" "e-d-16" ];
    #}
    #{
    #  name = "e-b-17";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 132;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-17" "e-c-17" "e-d-17" ];
    #}
    #{
    #  name = "e-b-18";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 133;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-18" "e-c-18" "e-d-18" ];
    #}
    #{
    #  name = "e-b-19";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 134;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-19" "e-c-19" "e-d-19" ];
    #}
    #{
    #  name = "e-b-20";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 135;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-20" "e-c-20" "e-d-20" ];
    #}

    ## e-b-21 - 25 edge nodes

    #{
    #  name = "e-b-21";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 136;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-22" "e-b-23" "e-b-24" "e-b-25" "e-a-21" "e-c-21" "e-d-21" ];
    #}
    #{
    #  name = "e-b-22";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 137;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-23" "e-b-24" "e-b-25" "e-a-22" "e-c-22" "e-d-22" ];
    #}
    #{
    #  name = "e-b-23";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 138;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-24" "e-b-25" "e-a-23" "e-c-23" "e-d-23" ];
    #}
    #{
    #  name = "e-b-24";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 139;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-25" "e-a-24" "e-c-24" "e-d-24" ];
    #}
    #{
    #  name = "e-b-25";
    #  region = "ap-northeast-1";
    #  org = "IOHK";
    #  nodeId = 140;
    #  producers = [ "b-b-1" "e-b-1" "e-b-2" "e-b-3" "e-b-4" "e-b-5" "e-b-6" "e-b-7" "e-b-8" "e-b-9" "e-b-10" "e-b-11" "e-b-12" "e-b-13" "e-b-14" "e-b-15" "e-b-16" "e-b-17" "e-b-18" "e-b-19" "e-b-20" "e-b-21" "e-b-22" "e-b-23" "e-b-24" "e-a-25" "e-c-25" "e-d-25" ];
    #}

    # e-c-1 - 5 edge nodes

    {
      name = "e-c-1";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 11;
      producers = [ "b-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-a-1" "e-b-1" "e-d-1" ];
    }
    {
      name = "e-c-2";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 27;
      producers = [ "b-c-1" "e-c-1" "e-c-3" "e-c-4" "e-c-5" "e-a-2" "e-b-2" "e-d-2" ];
    }
    {
      name = "e-c-3";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 28;
      producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-4" "e-c-5" "e-a-3" "e-b-3" "e-d-3" ];
    }
    {
      name = "e-c-4";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 29;
      producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-5" "e-a-4" "e-b-4" "e-d-4" ];
    }
    {
      name = "e-c-5";
      region = "ap-southeast-1";
      org = "IOHK";
      nodeId = 30;
      producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-a-5" "e-b-5" "e-d-5" ];
    }

    # e-c-6 - 10 edge nodes

    #{
    #  name = "e-c-6";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 141;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-6" "e-b-6" "e-d-6" ];
    #}
    #{
    #  name = "e-c-7";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 142;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-7" "e-b-7" "e-d-7" ];
    #}
    #{
    #  name = "e-c-8";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 143;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-8" "e-b-8" "e-d-8" ];
    #}
    #{
    #  name = "e-c-9";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 144;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-9" "e-b-9" "e-d-9" ];
    #}
    #{
    #  name = "e-c-10";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 145;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-10" "e-b-10" "e-d-10" ];
    #}

    ## e-c-11 - 15 edge nodes

    #{
    #  name = "e-c-11";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 146;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-11" "e-b-11" "e-d-11" ];
    #}
    #{
    #  name = "e-c-12";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 147;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-12" "e-b-12" "e-d-12" ];
    #}
    #{
    #  name = "e-c-13";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 148;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-13" "e-b-13" "e-d-13" ];
    #}
    #{
    #  name = "e-c-14";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 149;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-14" "e-b-14" "e-d-14" ];
    #}
    #{
    #  name = "e-c-15";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 150;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-15" "e-b-15" "e-d-15" ];
    #}

    ## e-c-16 - 20 edge nodes

    #{
    #  name = "e-c-16";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 151;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-16" "e-b-16" "e-d-16" ];
    #}
    #{
    #  name = "e-c-17";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 152;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-17" "e-b-17" "e-d-17" ];
    #}
    #{
    #  name = "e-c-18";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 153;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-18" "e-b-18" "e-d-18" ];
    #}
    #{
    #  name = "e-c-19";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 154;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-19" "e-b-19" "e-d-19" ];
    #}
    #{
    #  name = "e-c-20";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 155;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-20" "e-b-20" "e-d-20" ];
    #}

    ## e-c-21 - 25 edge nodes

    #{
    #  name = "e-c-21";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 156;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-22" "e-c-23" "e-c-24" "e-c-25" "e-a-21" "e-b-21" "e-d-21" ];
    #}
    #{
    #  name = "e-c-22";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 157;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-23" "e-c-24" "e-c-25" "e-a-22" "e-b-22" "e-d-22" ];
    #}
    #{
    #  name = "e-c-23";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 158;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-24" "e-c-25" "e-a-23" "e-b-23" "e-d-23" ];
    #}
    #{
    #  name = "e-c-24";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 159;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-25" "e-a-24" "e-b-24" "e-d-24" ];
    #}
    #{
    #  name = "e-c-25";
    #  region = "ap-southeast-1";
    #  org = "IOHK";
    #  nodeId = 160;
    #  producers = [ "b-c-1" "e-c-1" "e-c-2" "e-c-3" "e-c-4" "e-c-5" "e-c-6" "e-c-7" "e-c-8" "e-c-9" "e-c-10" "e-c-11" "e-c-12" "e-c-13" "e-c-14" "e-c-15" "e-c-16" "e-c-17" "e-c-18" "e-c-19" "e-c-20" "e-c-21" "e-c-22" "e-c-23" "e-c-24" "e-a-25" "e-b-25" "e-d-25" ];
    #}

    # e-d-1 - 5 edge nodes

    {
      name = "e-d-1";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 12;
      producers = [ "b-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-a-1" "e-b-1" "e-c-1" ];
    }
    {
      name = "e-d-2";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 31;
      producers = [ "b-d-1" "e-d-1" "e-d-3" "e-d-4" "e-d-5" "e-a-2" "e-b-2" "e-c-2" ];
    }
    {
      name = "e-d-3";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 32;
      producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-4" "e-d-5" "e-a-3" "e-b-3" "e-c-3" ];
    }
    {
      name = "e-d-4";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 33;
      producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-5" "e-a-4" "e-b-4" "e-c-4" ];
    }
    {
      name = "e-d-5";
      region = "us-east-2";
      org = "IOHK";
      nodeId = 34;
      producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-a-5" "e-b-5" "e-c-5" ];
    }

    # e-d-6 - 10 edge nodes

    #{
    #  name = "e-d-6";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 161;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-6" "e-b-6" "e-c-6" ];
    #}
    #{
    #  name = "e-d-7";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 162;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-7" "e-b-7" "e-c-7" ];
    #}
    #{
    #  name = "e-d-8";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 163;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-8" "e-b-8" "e-c-8" ];
    #}
    #{
    #  name = "e-d-9";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 164;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-9" "e-b-9" "e-c-9" ];
    #}
    #{
    #  name = "e-d-10";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 165;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-10" "e-b-10" "e-c-10" ];
    #}

    ## e-d-11 - 15 edge nodes

    #{
    #  name = "e-d-11";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 166;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-11" "e-b-11" "e-c-11" ];
    #}
    #{
    #  name = "e-d-12";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 167;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-12" "e-b-12" "e-c-12" ];
    #}
    #{
    #  name = "e-d-13";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 168;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-13" "e-b-13" "e-c-13" ];
    #}
    #{
    #  name = "e-d-14";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 169;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-14" "e-b-14" "e-c-14" ];
    #}
    #{
    #  name = "e-d-15";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 170;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-15" "e-b-15" "e-c-15" ];
    #}

    ## e-d-16 - 20 edge nodes

    #{
    #  name = "e-d-16";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 171;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-16" "e-b-16" "e-c-16" ];
    #}
    #{
    #  name = "e-d-17";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 172;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-17" "e-b-17" "e-c-17" ];
    #}
    #{
    #  name = "e-d-18";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 173;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-18" "e-b-18" "e-c-18" ];
    #}
    #{
    #  name = "e-d-19";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 174;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-19" "e-b-19" "e-c-19" ];
    #}
    #{
    #  name = "e-d-20";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 175;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-20" "e-b-20" "e-c-20" ];
    #}

    ## e-d-21 - 25 edge nodes

    #{
    #  name = "e-d-21";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 176;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-22" "e-d-23" "e-d-24" "e-d-25" "e-a-21" "e-b-21" "e-c-21" ];
    #}
    #{
    #  name = "e-d-22";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 177;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-23" "e-d-24" "e-d-25" "e-a-22" "e-b-22" "e-c-22" ];
    #}
    #{
    #  name = "e-d-23";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 178;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-24" "e-d-25" "e-a-23" "e-b-23" "e-c-23" ];
    #}
    #{
    #  name = "e-d-24";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 179;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-25" "e-a-24" "e-b-24" "e-c-24" ];
    #}
    #{
    #  name = "e-d-25";
    #  region = "us-east-2";
    #  org = "IOHK";
    #  nodeId = 180;
    #  producers = [ "b-d-1" "e-d-1" "e-d-2" "e-d-3" "e-d-4" "e-d-5" "e-d-6" "e-d-7" "e-d-8" "e-d-9" "e-d-10" "e-d-11" "e-d-12" "e-d-13" "e-d-14" "e-d-15" "e-d-16" "e-d-17" "e-d-18" "e-d-19" "e-d-20" "e-d-21" "e-d-22" "e-d-23" "e-d-24" "e-a-25" "e-b-25" "e-c-25" ];
    #}
  ];
}
