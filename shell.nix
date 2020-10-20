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

in  mkShell (rec {
  buildInputs = [
    awscli2
    bashInteractive
    cardano-cli
    dnsutils
    iohkNix.niv
    nivOverrides
    nix
    nix-diff
    nixops
    pandoc
    perl
    pstree
    telnet
    cardano-ping
    relayUpdateTimer
  ] ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux ([
    # Those fail to compile under macOS:
    node-update
    # script NOT for use on mainnet:
  ] ++ lib.optional (globals.environmentName != "mainnet") kes-rotation));
  # If any build input has bash completions, add it to the search
  # path for shell completions.
  XDG_DATA_DIRS = lib.concatStringsSep ":" (
    [(builtins.getEnv "XDG_DATA_DIRS")] ++
    (lib.filter
      (share: builtins.pathExists (share + "/bash-completion"))
      (map (p: p + "/share") buildInputs))
  );

  NIX_PATH = "nixpkgs=${path}";
  NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
  passthru = {
    gen-graylog-creds = iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
  };
} // globals.environmentVariables)
