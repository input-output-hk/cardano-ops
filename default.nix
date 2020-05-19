{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
, pkgs ? import ./nix { inherit system crossSystem config; }
}: with pkgs; {

  shell = import ./shell.nix { inherit pkgs; };
}
