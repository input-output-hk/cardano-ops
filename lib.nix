{ ... }@args:
let
  sources = import ./nix/sources.nix;
  iohkNix = import sources.iohk-nix args;
  # Note that this repo is using the iohk-nix nixpkgs by default
  # A niv nixpkgs pin can override this with the following line:
  #iohkNix = import sources.iohk-nix ({ nixpkgsOverride = sources.nixpkgs; } // args);
in iohkNix
