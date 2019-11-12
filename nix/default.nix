{ sourcePaths ? import ./sources.nix
, system ? builtins.currentSystem
, crossSystem ? null
, config ? {} }:
import sourcePaths.nixpkgs {
  overlays = import ../overlays sourcePaths;
  inherit system crossSystem config;
}
