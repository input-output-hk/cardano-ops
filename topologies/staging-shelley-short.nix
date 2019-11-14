{
  legacyCoreNodes = [
   {
      name = "c-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-2" "c-a-3" ]
        [ "c-b-1" "c-b-2" ]
        [ "r-a-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-3" "c-a-1" ]
        [ "c-c-2" "c-c-1" ]
        [ "r-a-2" "r-a-3" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-a-3";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "r-a-3" "r-a-1" ]
        [ "r-b-1" "r-c-1" ]
      ];
      org = "IOHK";
    }
    {
      name = "c-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "r-b-2" ]
        [ "c-c-1" "c-c-2" ]
        [ "r-b-1" "r-b-2" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-a-2" "c-a-1" ]
        [ "c-b-1" "r-b-1" ]
        [ "r-b-2" "r-b-1" ]
      ];
      org = "Emurgo";
    }
    {
      name = "c-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "c-c-2" "r-c-1" ]
        [ "r-c-1" "r-c-2" ]
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
      ];
      org = "CF";
    }
    {
      name = "r-a-1";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-3" ]
        [ "c-a-2" "c-a-3" ]
        [ "r-a-2" "r-a-3" ]
        [ "r-b-1" "r-b-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-2";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-1" "c-a-2" ]
        [ "c-a-3" "c-a-2" ]
        [ "r-a-3" "r-a-1" ]
        [ "r-c-1" "r-c-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-a-3";
      region = "eu-central-1";
      staticRoutes = [
        [ "c-a-2" "c-a-1" ]
        [ "c-a-3" "c-a-1" ]
        [ "r-a-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-1";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-1" "c-b-2" ]
        [ "r-a-1" "r-a-3" ]
        [ "r-b-2" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-b-2";
      region = "ap-northeast-1";
      staticRoutes = [
        [ "c-b-2" "c-b-1" ]
        [ "r-b-1" "r-a-2" ]
        [ "r-c-1" "r-c-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-1";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-1" "c-c-2" ]
        [ "r-a-3" "r-a-2" ]
        [ "r-c-2" "r-a-2" ]
      ];
      org = "IOHK";
    }
    {
      name = "r-c-2";
      region = "ap-southeast-1";
      staticRoutes = [
        [ "c-c-2" "c-c-1" ]
        [ "r-b-2" "r-b-1" ]
        [ "r-c-1" "r-a-2" ]
      ];
      org = "IOHK";
    }
  ];

  legacyRelayNodes = [];

  byronProxies = [
    {
      name = "p-a-1";
      region = "eu-central-1";
      org = "IOHK";
    }
  ];

  coreNodes = [

  ];

  relayNodes = [

  ];

}
