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
with pkgs; with lib;
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  nixopsFlake = builtins.getFlake "github:input-output-hk/nixops-flake/be0a1add8655c138f2251c42c421f271844bdb09";
  nivOverrides = writeShellScriptBin "niv-overrides" ''
    niv --sources-file ${toString globals.sourcesJsonOverride} $@
  '';

in mkShell (globals.environmentVariables // {
  nativeBuildInputs = [
    awscli2
    bashInteractive
    cardano-cli
    dnsutils
    niv
    locli
    nivOverrides
    nix
    nix-diff
    pandoc
    perl
    pstree
    telnet
    git
    direnv
    nix-direnv
    lorri
    relayUpdateTimer
    snapshotStatesTimer
    s3cmd
    icdiff
  ] ++ (if (globals.withNixopsExperimental && isLinux) then [
    # Required for libvirtd usage -- the ops-lib nixops overlay has an incompat embedded qemu version
    nixopsFlake.legacyPackages.${builtins.currentSystem}.nixops_1_8-nixos-unstable
  ] else [
    nixops
  ]) ++ (lib.optionals isLinux ([
    # Those fail to compile under macOS:
    node-update
    snapshot-states
    # script NOT for use on mainnet:
  ] ++ lib.optional (globals.environmentName != "mainnet") kes-rotation));

  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";

  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
})
