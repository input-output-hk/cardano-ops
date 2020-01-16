# This role is used to add a `relay` role to a legacyCoreNode
# as part of a two step process to migrate from legacyCoreNode
# to coreNode.  The relay allows a sync to the tip of the
# nonlegacy chain state without having to stop the legacy core
# function during the sync
{ pkgs, ... }:
{
  imports = [
    ./relay.nix
  ];

  node.roles.isCardanoRelay = true;
  services.cardano-node = {
    producers = ["p-a-1" "c-c-2" "e-b-1" "e-c-1"];
  };
  users.users.cardano-node.uid = pkgs.lib.mkForce 10014;
  users.groups.cardano-node.gid = pkgs.lib.mkForce 123123;
  users.users.cardano-node.description = pkgs.lib.mkForce "cardano-node server user";
}
