pkgs: with pkgs; with lib; with topology-lib; {
  coreNodes = [
    {
      name = "a";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c"];
    }
    {
      name = "b";
      nodeId = 2;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["c" "a"];
    }
    {
      name = "c";
      nodeId = 3;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "b"];
    }
  ];

  relayNodes = [];
}
