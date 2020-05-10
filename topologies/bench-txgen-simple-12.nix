{
  coreNodes = [
    {
      name = "a";
      nodeId = 0;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "b";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "c";
      nodeId = 2;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "b" "d" "e" "f" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "d";
      nodeId = 3;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["a" "b" "c" "e" "f" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "e";
      nodeId = 4;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "c" "d" "f" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "f";
      nodeId = 5;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "c" "d" "e" "g" "h" "i" "j" "k" "l"];
    }
    {
      name = "g";
      nodeId = 6;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "c" "d" "e" "f" "h" "i" "j" "k" "l"];
    }
    {
      name = "h";
      nodeId = 7;
      org = "IOHK";
      region = "ap-southeast-2";
      producers = ["a" "b" "c" "d" "e" "f" "g" "i" "j" "k" "l"];
    }

    {
      name = "i";
      nodeId = 8;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "e" "f" "g" "h" "j" "k" "l"];
    }
    {
      name = "j";
      nodeId = 9;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "e" "f" "g" "h" "i" "k" "l"];
    }
    {
      name = "k";
      nodeId = 10;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "l"];
    }
    {
      name = "l";
      nodeId = 11;
      org = "IOHK";
      region = "us-east-1";
      producers = ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k"];
    }
  ];

  relayNodes = [];

  legacyCoreNodes = [];

  legacyRelayNodes = [];

  byronProxies = [];
}
