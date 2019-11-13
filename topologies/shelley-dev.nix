{
  coreNodes = [
    {
      name = "a1";
      region = "eu-central-1";
      staticRoutes = [["b1"] ["r1"] ["c1"]];
    }
    {
      name = "b1";
      region = "eu-west-1";
      staticRoutes = [["c1"] ["r2"] ["a1"]];
    }
    {
      name = "c1";
      region = "ap-southeast-1";
      staticRoutes = [["a1"] ["r3"] ["b1"]];
    }
    #{
    #  name = "d1";
    #  region = "eu-central-1";
    #  staticRoutes = [["a1" "b1"] ["c1"]];
    #}
  ];

  relayNodes = [
    {
      name = "r1";
      region = "ap-southeast-1";
      staticRoutes = [["a1"] ["b1"]];
    }
    {
      name = "r2";
      region = "eu-central-1";
      staticRoutes = [["b1"] ["c1"]];
    }
    {
      name = "r3";
      region = "eu-central-1";
      staticRoutes = [["c1"] ["d1"]];
    }
  ];
}
