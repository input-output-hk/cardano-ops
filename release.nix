# Temporary release.nix

{ cardano-ops ? { outPath = ./.; rev = "abcdef"; } }:
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in pkgs.lib.fix (self: {
  forceNewEval = pkgs.writeText "forceNewEval" cardano-ops.rev;
  required = pkgs.releaseTools.aggregate {
    name = "required";
    constituents = with self; [
      forceNewEval
    ];
  };
})

# -----------

#############################################################################
##
## Hydra release jobset.
##
## The purpose of this file is to select jobs defined in default.nix and map
## them to all supported build platforms.
##
#############################################################################
#
## The project sources
#{ cardano-ops ? { outPath = ./.; rev = "abcdef"; }
#
## Function arguments to pass to the project
#, projectArgs ? { config = { allowUnfree = false; inHydra = true; }; }
#
## The systems that the jobset will be built for.
#, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" ]
#
## The systems used for cross-compiling
#, supportedCrossSystems ? [ "x86_64-linux" ]
#
## A Hydra option
#, scrubJobs ? true
#
## Import pkgs (sourcesOverride is defnd independently in ./nix/default.nix
#, pkgs ? import ./nix {}
#}:
#
#with import pkgs.iohkNix.release-lib {
#  inherit pkgs;
#  inherit supportedSystems supportedCrossSystems scrubJobs projectArgs;
#  packageSet = import cardano-ops;
#  gitrev = cardano-ops.rev;
#};
#
#with pkgs.lib;
#
#let
#  jobs = {
#    native = mapTestOn (packagePlatforms project);
#  }
#  // {
#    # This aggregate job is what IOHK Hydra uses to update
#    # the CI status in GitHub.
#    required = mkRequiredJob (
#      # project executables:
#      [
#        # jobs.native.BUILD-ME.x86_64-linux
#      ]
#    );
#  };
#  # Build the shell derivation in Hydra so that all its dependencies
#  # are cached.
#  # // mapTestOn (packagePlatforms { inherit (project) shell; });
#
#in jobs
