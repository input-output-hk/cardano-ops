##
## This allows us to build cardano-ops-like shells with deployment capability.
##
{ pkgs }:

let
  inherit (pkgs) globals lib;
  nivOverrides = pkgs.writeShellScriptBin "niv-overrides" ''
    niv --sources-file ${toString globals.sourcesJsonOverride} $@
  '';
in
{
  nativeBuildInputs =
    with pkgs;
    [
    awscli2
    bashInteractive
    cardano-cli
    dnsutils
    niv
    locli.components.exes.locli
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
  ] ++ (lib.optionals stdenv.hostPlatform.isLinux ([
    # Those fail to compile under macOS:
    node-update
    # script NOT for use on mainnet:
  ] ++ lib.optional (globals.environmentName != "mainnet") kes-rotation));

  passthru =
    {
      gen-graylog-creds = lib.iohk-ops-lib.scripts.gen-graylog-creds { staticPath = ./static; };
    };

  extraMkShellAttributes =
    {
      NIX_PATH = "nixpkgs=${pkgs.path}";
      NIXOPS_DEPLOYMENT = "${globals.deploymentName}";
    }
    // globals.environmentVariables;

  cardanoOpsMkShellDefault =
    with pkgs;

    ## Note: we're using the non-rec, verbose, pkgs-relative references on purpose:
    ##       this serves as a reference on how to define a derived shell.
    mkShell
      ({
        inherit (cardano-ops.deployment-shell) nativeBuildInputs passthru;
       }
       // cardano-ops.deployment-shell.extraMkShellAttributes);
}
