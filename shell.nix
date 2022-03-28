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
  nivOverrides = writeShellScriptBin "niv-overrides" ''
    niv --sources-file ${toString globals.sourcesJsonOverride} $@
  '';

in  mkShell (globals.environmentVariables // {
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
    nixops
    pandoc
    perl
    pstree
    telnet
    cardano-ping
    git
    direnv
    nix-direnv
    lorri
    relayUpdateTimer
    dbSyncSnapshotTimer
    s3cmd
  ] ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux ([
    # Those fail to compile under macOS:
    node-update
    db-sync-snapshot
    # script NOT for use on mainnet:
  ] ++ lib.optional (globals.environmentName != "mainnet") kes-rotation));

  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";

  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
})
