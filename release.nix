{ cardano-ops ? { outPath = ./.; rev = "abcdef"; } }:
let
  sources = import ./nix/sources.nix;
  pkgs = import ./nix {};

in pkgs.lib.fix (self: {
  inherit (pkgs)
    kes-rotation
    nginxExplorer
    node-update
    prometheus-varnish-exporter
    varnishPackages;

  shell = import ./shell.nix { inherit pkgs; };

  forceNewEval = pkgs.writeText "forceNewEval" cardano-ops.rev;

  required = pkgs.releaseTools.aggregate {
    name = "required";
    constituents = with self; [
      forceNewEval
      kes-rotation
      nginxExplorer
      node-update
      prometheus-varnish-exporter
      varnishPackages.varnish
      varnishPackages.modules
      shell
    ];
  };
})
