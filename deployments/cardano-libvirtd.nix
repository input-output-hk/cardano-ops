import ../clusters/cardano.nix (with (import ../nix {}).iohk-ops-lib.physical.libvirtd; {
  inherit targetEnv medium;
  xlarge = large;
  xlarge-monitor = large;
})
