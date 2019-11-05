{ region, accessKeyId, ... }: let port = 3001; in {
  "allow-cardano-node-${region}" = {
    inherit accessKeyId region;
    _file = ./allow-cardano-node.nix;
    description = "Allow all tcp on ${toString port}";
    rules = [{
      protocol = "tcp";
      fromPort = port;
      toPort = port;
      sourceIp = "0.0.0.0/0";
    }];
  };
}
