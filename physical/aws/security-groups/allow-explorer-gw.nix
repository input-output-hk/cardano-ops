{ region, org, pkgs, lib, ... }@args:
with lib; {
  "allow-to-explorer-backends" = { resources, ... }: {
    inherit region;
    accessKeyId = pkgs.globals.ec2.credentials.accessKeyIds.${org};
    _file = ./allow-explorer-gw.nix;
    description = "Allow to TCP/80,81 from explorer gateway";
    rules = [{
      protocol = "tcp";
      fromPort = 80;
      toPort = 81;
      sourceIp = resources.elasticIPs."explorer-ip";
    }];
  } // optionalAttrs (args ? vpcId) {
    vpcId = resources.vpc.${args.vpcId};
  };
}
