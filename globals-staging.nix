pkgs: {

  deploymentName = "rc-staging";

  dnsZone = "${pkgs.globals.domain}";

  domain = "awstest.iohkdev.io";

  environmentName = "staging";

  explorerAliases = [];
  withHighLoadRelays = true;

  topology = import ./topologies/staging.nix;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "iohk";
        Emurgo = "fifth-party";
        CF = "third-party";
        dns = "dns";
      };
    };
  };
}
