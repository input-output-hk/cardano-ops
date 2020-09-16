with import ../nix {};

import ../clusters/cardano.nix (with iohk-ops-lib.physical.libvirtd; {
  inherit targetEnv medium pkgs;
  nano = tiny;
  small = tiny;
  xlarge = large;
  xlarge-monitor = large;
  m5ad-xlarge = large;
  t3-xlarge = large;
  t3-2xlarge-monitor = large;
  c5-4xlarge = large;
}) // lib.optionalAttrs (builtins.getEnv "BUILD_ONLY" == "true") {
  defaults = {
    users.users.root.openssh.authorizedKeys.keys = lib.mkForce [""];
  };
}
