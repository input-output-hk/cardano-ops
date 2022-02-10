{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
}:
let
  defaultSourcePaths = import ./sources.nix { inherit pkgs; };

  # use our own nixpkgs if it exists in our sources,
  # otherwise use iohkNix default nixpkgs.
  defaultNixpkgs = if (defaultSourcePaths ? nixpkgs)
    then defaultSourcePaths.nixpkgs
    else (import defaultSourcePaths.iohk-nix {}).nixpkgs;

  inherit (import defaultNixpkgs { overlays = [globalsOverlay]; }) globals;

  sourcesOverride = let sourcesFile = globals.sourcesJsonOverride; in
    if (builtins.pathExists sourcesFile)
    then import ./sources.nix { inherit pkgs sourcesFile; }
    else {};

  sourcePaths = defaultSourcePaths // sourcesOverride;

  iohkNix = import sourcePaths.iohk-nix {};

  nixpkgs = if (sourcesOverride ? nixpkgs) then sourcesOverride.nixpkgs else defaultNixpkgs;

  # overlays from ops-lib (include ops-lib sourcePaths):
  ops-lib-overlays = (import sourcePaths.ops-lib { withRustOverlays = false; sourcesOverride = sourcePaths; }).overlays;
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

  varnish-overlay = self: super: {
    varnish70Packages = super.varnish70Packages // {
      varnish = super.varnish70Packages.varnish.overrideAttrs (oA: {
        # Work-around excessive malloc overhead (https://github.com/varnishcache/varnish-cache/issues/3511#issuecomment-773889001)
        buildInputs = oA.buildInputs ++ [ self.jemalloc ];
        buildFlags = oA.buildFlags ++ [ "JEMALLOC_LDADD=${self.jemalloc}/lib/libjemalloc.so" ];
      });
      modules = (self.callPackages ../pkgs/varnish/modules.nix { varnish = self.varnish70Packages.varnish; }).modules19;
    };
    varnish60Packages = super.varnish60Packages // {
      varnish = super.varnish60Packages.varnish.overrideAttrs (oA: {
        buildInputs = oA.buildInputs ++ [ self.jemalloc ];
        buildFlags = oA.buildFlags ++ [ "JEMALLOC_LDADD=${self.jemalloc}/lib/libjemalloc.so" ];
      });
      modules = (self.callPackages ../pkgs/varnish/modules.nix { varnish = self.varnish60Packages.varnish; }).modules15;
    };
    prometheus-varnish-exporter = super.prometheus-varnish-exporter.override {
      buildGoModule = args: self.buildGoModule (args // rec {
        version = "1.6.1";
        src = self.fetchFromGitHub {
          owner = "jonnenauha";
          repo = "prometheus_varnish_exporter";
          rev = version;
          sha256 = "15w2ijz621caink2imlp1666j0ih5pmlj62cbzggyb34ncl37ifn";
        };
        vendorSha256 = "sha256-P2fR0U2O0Y4Mci9jkAMb05WR+PrpuQ59vbLMG5b9KQI=";
      });
    };
  };

  traefik-overlay = self: super: {
    traefik = super.traefik.override {
      buildGoModule = args: self.buildGoModule (args // rec {
        version = "2.5.6";
        src = self.fetchzip {
          url = "https://github.com/traefik/traefik/releases/download/v${version}/traefik-v${version}.src.tar.gz";
          sha256 = "sha256-HHJTfAigUH7C0VuKUeGypqFlQwVdy05Ki/aTxDsl+tg=";
          stripRoot = false;
        };
        vendorSha256 = "sha256-DqjqJPyoFlCjIIaHYS5jrROQWDxZk+RGfccC2jYZ8LE=";
      });
    };
  };

  # our own overlays:
  local-overlays = [
    (import ./cardano.nix)
    (import ./packages.nix)
  ];

  globalsOverlay =
    if builtins.pathExists ../globals.nix
    then (pkgs: _: with pkgs.lib; let
      globalsDefault = import ../globals-defaults.nix pkgs;
      globalsSpecific = import ../globals.nix pkgs;
    in {
      globals = globalsDefault // (recursiveUpdate {
        inherit (globalsDefault) ec2 libvirtd environmentVariables;
      } globalsSpecific);
    })
    else builtins.trace "globals.nix missing, please add symlink" (pkgs: _: {
      globals = import ../globals-defaults.nix pkgs;
    });

  # merge upstream sources with our own:
  upstream-overlay = self: super: {
      inherit iohkNix;
    cardano-ops = {
      inherit overlays;
      modules = self.importWithPkgs ../modules;
      roles = self.importWithPkgs ../roles;
    };
    sourcePaths = (super.sourcePaths or {}) // sourcePaths;
  };

  overlays =
    ops-lib-overlays ++
    local-overlays ++
    [
      upstream-overlay
      nginx-overlay
      varnish-overlay
      traefik-overlay
      globalsOverlay
      globals.overlay
    ];

    pkgs = import nixpkgs {
      inherit system crossSystem config overlays;
    };
in
  pkgs
