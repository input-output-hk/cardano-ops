with import ../nix {};

import ../clusters/cardano.nix {
  inherit pkgs;
  inherit (globals.packet) instances;
};
