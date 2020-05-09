
{config, name, lib, ...}:
with import ../nix {};
let
  nodeId = toString config.node.nodeId;
  vrfKey = ../keys/node-keys/node-vrf + "${nodeId}.skey";
  kesKey = ../keys/node-keys/node-kes + "${nodeId}.skey";
  operationalCertificate = ../keys/node-keys/delegate + "${nodeId}.opcert";
in {

  imports = [
    ../modules/base-service.nix
  ];

  services.cardano-node = {
    kesKey = "/var/lib/keys/cardano-node-kes-signing";
    vrfKey = "/var/lib/keys/cardano-node-vrf-signing";
    operationalCertificate = "/var/lib/keys/cardano-node-operational-cert";
  };

  systemd.services."cardano-node" = {
    after = [ "cardano-node-vrf-signing-key.service" "cardano-node-kes-signing-key.service" "cardano-node-operational-cert-key.service" ];
    wants = [ "cardano-node-vrf-signing-key.service" "cardano-node-kes-signing-key.service" "cardano-node-operational-cert-key.service" ];
  };

  users.users.cardano-node.extraGroups = [ "keys" ];

  deployment.keys = {
    "cardano-node-vrf-signing" = builtins.trace ("${name}: using " + (toString vrfKey)) {
        keyFile = vrfKey;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-kes-signing" = builtins.trace ("${name}: using " + (toString kesKey)) {
        keyFile = kesKey;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
    "cardano-node-operational-cert" = builtins.trace ("${name}: using " + (toString operationalCertificate)) {
        keyFile = operationalCertificate;
        user = "cardano-node";
        group = "cardano-node";
        destDir = "/var/lib/keys";
    };
  };

}
