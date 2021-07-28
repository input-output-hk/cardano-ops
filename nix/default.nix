{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
, deploymentGlobalsFn ? ## :: Pkgs -> GlobalsOverlayOverDefaults
    pkgs:
    if builtins.pathExists ../globals.nix
    then import ../globals.nix pkgs
    else builtins.trace "globals.nix missing, please add symlink" {}
}:
let
  defaultSourcePaths = import ./sources.nix { inherit pkgs; };

  # use our own nixpkgs if it exists in our sources,
  # otherwise use iohkNix default nixpkgs.
  defaultNixpkgs = if (defaultSourcePaths ? nixpkgs)
    then defaultSourcePaths.nixpkgs
    else (import defaultSourcePaths.iohk-nix {}).nixpkgs;

  sourcesOverride = let sourcesFile = ((import defaultNixpkgs { overlays = globals; }).globals).sourcesJsonOverride; in
    if (builtins.pathExists sourcesFile)
    then import ./sources.nix { inherit pkgs sourcesFile; }
    else {};

  sourcePaths = defaultSourcePaths // sourcesOverride;

  iohkNix = import sourcePaths.iohk-nix {};

  nixpkgs = if (sourcesOverride ? nixpkgs) then sourcesOverride.nixpkgs else defaultNixpkgs;

  # overlays from ops-lib (include ops-lib sourcePaths):
  ops-lib-overlays = (import sourcePaths.ops-lib { withRustOverlays = false; }).overlays;
  nginx-overlay = self: super: let
    acceptLanguage = {
      src = self.fetchFromGitHub {
        name = "nginx_accept_language_module";
        owner = "giom";
        repo = "nginx_accept_language_module";
        rev = "2f69842f83dac77f7d98b41a2b31b13b87aeaba7";
        sha256 = "1hjysrl15kh5233w7apq298cc2bp4q1z5mvaqcka9pdl90m0vhbw";
      };
    };
  in rec {
    luajit = super.luajit.withPackages (ps: with ps; [cjson]);
    nginxExplorer = super.nginxStable.override (oldAttrs: {
      modules = oldAttrs.modules ++ [
        acceptLanguage
        self.nginxModules.develkit
        self.nginxModules.lua
      ];
    });
    nginxSmash = super.nginxStable.override (oldAttrs: {
      modules = oldAttrs.modules ++ [
        self.nginxModules.develkit
        self.nginxModules.lua
      ];
    });
    nginxMetadataServer = nginxSmash;
  };

  varnish-overlay = self: super: rec {
    inherit (super.callPackages ../pkgs/varnish {})
      varnish60
      varnish61
      varnish62
      varnish63
      varnish64
      varnish65;

    inherit (super.callPackages ../pkgs/varnish/packages.nix { inherit
      varnish60
      varnish61
      varnish62
      varnish63
      varnish64
      varnish65;
    })
      varnish60Packages
      varnish61Packages
      varnish62Packages
      varnish63Packages
      varnish64Packages
      varnish65Packages;

    varnishPackages = varnish65Packages;
    varnish = varnishPackages.varnish;
    varnish-modules = varnishPackages.modules;

    prometheus-varnish-exporter = super.callPackage ../pkgs/prometheus-varnish-exporter {};
  };

  # our own overlays:
  local-overlays = [
    (import ./cardano.nix)
    (import ./benchmarking.nix)
    (import ./packages.nix)
  ];

  buildGlobals =
    specificGlobalsFn:

    [(pkgs: _: with pkgs.lib; let
      globalsDefault = import ../globals-defaults.nix pkgs;
      globalsSpecific = specificGlobalsFn pkgs;
    in {
      globals = globalsDefault // (recursiveUpdate {
        inherit (globalsDefault) ec2 libvirtd environmentVariables;
      } globalsSpecific);
    })];

  globals = buildGlobals deploymentGlobalsFn;

  # merge upstream sources with our own:
  upstream-overlay = self: super: {
      inherit iohkNix;
    cardano-ops = {
      inherit overlays;
      modules = self.importWithPkgs ../modules;
      roles = self.importWithPkgs ../roles;
      deployment-shell = import ./deployment-shell.nix { pkgs = self; };
    };
    sourcePaths = (super.sourcePaths or {}) // sourcePaths;
  };

  overlays =
    ops-lib-overlays ++
    local-overlays ++
    globals ++
    [
      upstream-overlay
      nginx-overlay
      varnish-overlay
    ];

  pkgs = import nixpkgs {
    inherit system crossSystem config overlays;
  };
in
  pkgs
