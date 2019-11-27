{
  coreNodes = [
    {
      name = "a";
      nodeId = 0;
      region = "eu-central-1";
      producers = ["b" "c"];
    }
    {
      name = "b";
      nodeId = 1;
      region = "eu-central-1";
      producers = ["c" "a"];
    }
    {
      name = "c";
      nodeId = 2;
      region = "eu-central-1";
      producers = ["a" "b"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
