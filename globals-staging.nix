pkgs: {

  deploymentName = "rc-staging";
  deploymentPath = "$HOME/staging";

  dnsZone = "${pkgs.globals.domain}";

  domain = "staging.cardano.org";

  environmentName = "staging";

  withSubmitApi = true;
  withSmash = true;
  withFaucet = true;
  faucetHostname = "faucet";

  explorerBackends = with pkgs.globals; {
    a = explorer10;
    b = explorer10;
  };
  explorerActiveBackends = [ "a" "b" ];

  topology = import ./topologies/staging.nix pkgs;

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "iohk";
        Emurgo = "fifth-party";
        CF = "third-party";
        dns = "dns";
      };
    };
    instances.relay-node = pkgs.iohk-ops-lib.physical.aws.t3-xlarge;
  };

  alertChainDensityLow = "90";
}
