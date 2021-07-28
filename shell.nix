# This derivation assumes a toplogy file where the following attributes are
# defined:
#
# - bftCoreNodes
# - stakePoolNodes
# - coreNodes
#
{ config ? {}
, pkgs ? import ./nix {
    inherit config;
  }
}:

## See the definition of `cardanoOpsMkShellDefault` for a reference implementation
##   of a cardano-ops-like shell with deployment capability.
pkgs.cardano-ops.deployment-shell.cardanoOpsMkShellDefault


