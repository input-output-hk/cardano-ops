with import ../nix {};

import ../clusters/cardano.nix {
  inherit pkgs;
  inherit (globals.libvirtd) instances;
} // lib.optionalAttrs (builtins.getEnv "BUILD_ONLY" == "true") {
  defaults = {
    users.users.root.openssh.authorizedKeys.keys = lib.mkForce [""];
  };
}
