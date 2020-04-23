{ sourcePaths ? import ./sources.nix
, system ? builtins.currentSystem
, crossSystem ? null
, config ? {} }:

let
  # overlays from ops-lib (include ops-lib sourcePaths):
  ops-lib-overlays = (import sourcePaths.ops-lib {}).overlays;
  nginx-explorer-overlay = self: super: let
    acceptLanguage = {
      src = self.fetchFromGitHub {
        name = "nginx_accept_language_module";
        owner = "giom";
        repo = "nginx_accept_language_module";
        rev = "2f69842f83dac77f7d98b41a2b31b13b87aeaba7";
        sha256 = "1hjysrl15kh5233w7apq298cc2bp4q1z5mvaqcka9pdl90m0vhbw";
      };
    };
  in {
    nginxExplorer = super.nginxStable.override (oldAttrs: {
      modules = oldAttrs.modules ++ [
        #self.nginxModules.vts
        acceptLanguage
      ];
    });
  };

  # our own overlays:
  local-overlays = [
    (import ./cardano.nix)
    (import ./packages.nix)
  ];

  globals =
    if builtins.pathExists ../globals.nix
    then [(self: _: {
      globals = import ../globals-defaults.nix self // import ../globals.nix self;
    })]
    else builtins.trace "globals.nix missing, please add symlink" [(self: _: {
      globals = import ../globals-defaults.nix self;
    })];

  # merge upstream sources with our own:
  upstream-overlay = _: super: {
    iohkNix = import sourcePaths.iohk-nix {};

    cardano-ops-overlays = overlays;
    sourcePaths = (super.sourcePaths or {}) // sourcePaths;
  };

  overlays =
    ops-lib-overlays ++
    local-overlays ++
    globals ++
    [
      upstream-overlay
      nginx-explorer-overlay
    ];
in
  import sourcePaths.nixpkgs {
    inherit overlays system crossSystem config;
  }
