{ region, org, pkgs, lib, ... }:
with lib; {
  "allow-wireguard" = { resources, ... }: {
    inherit region;
    accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
    _file = ./allow-wireguard.nix;
    description = "Allow to UDP/51820";
    rules = [{
      protocol = "udp";
      fromPort = 51820;
      toPort = 51820;
      sourceIp = "0.0.0.0/0";
      sourceIpv6 = "::/0";
    }];
  };
}
