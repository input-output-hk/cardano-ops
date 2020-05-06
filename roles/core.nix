
{config, name, lib, ...}:
with import ../nix {};
let
  nodeId = config.node.nodeId;
  leftPad = number: width: lib.fixedWidthString width "0" (toString number);
  signingKey = ../keys/delegate-keys + ".${leftPad nodeId 3}.key";
  delegationCertificate = ../keys/delegation-cert + ".${leftPad nodeId 3}.json";

in {

  imports = [
    ../modules/base-service.nix
  ];

  services.cardano-node = {
    signingKey = "/var/lib/keys/cardano-node-signing";
    delegationCertificate = "/var/lib/keys/cardano-node-delegation-cert";
  };

  systemd.services."cardano-node" = {
    after = [ "cardano-node-signing-key.service" "cardano-node-delegation-cert-key.service" ];
    wants = [ "cardano-node-signing-key.service" "cardano-node-delegation-cert-key.service" ];
  };

  users.users.cardano-node.extraGroups = [ "keys" ];

  deployment.keys = {
    "cardano-node-signing" = builtins.trace ("${name}: using " + (toString signingKey)) {
        keyFile = signingKey;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-delegation-cert" = builtins.trace ("${name}: using " + (toString delegationCertificate)) {
        keyFile = delegationCertificate;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
  };

}
