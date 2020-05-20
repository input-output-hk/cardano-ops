############################################################################
#
# Hydra release jobset.
#
# The purpose of this file is to select jobs defined in default.nix and map
# them to all supported build platforms.
#
############################################################################

# The project sources
{ cardano-ops ? { outPath = ./.; rev = "abcdef"; }

# Function arguments to pass to the project
, projectArgs ? { inherit sourcesOverride; config = { allowUnfree = false; inHydra = true; }; }

# The systems that the jobset will be built for.
, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" ]

# The systems used for cross-compiling
, supportedCrossSystems ? [ "x86_64-linux" ]

# A Hydra option
, scrubJobs ? true

# Import pkgs
, pkgs ? import ./nix { inherit sourcesOverride; }
}:

with import pkgs.iohkNix.release-lib {
  inherit pkgs;

  inherit supportedSystems supportedCrossSystems scrubJobs projectArgs;
  packageSet = import ops-lib;
  gitrev = ops-lib.rev;
};

with pkgs.lib;

let
  jobs = {
    native = mapTestOn (packagePlatforms project);
  }
  // {
    # This aggregate job is what IOHK Hydra uses to update
    # the CI status in GitHub.
    required = mkRequiredJob (
      # project executables:
      [ jobs.native.nixops.x86_64-linux
        jobs.native.nginxStable.x86_64-linux
        jobs.native.nginxMainline.x86_64-linux
      ]
    );
  }
  # Build the shell derivation in Hydra so that all its dependencies
  # are cached.
  // mapTestOn (packagePlatforms { inherit (project) shell; });

in jobs
