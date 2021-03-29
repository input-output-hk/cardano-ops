{ cardano-ops ? { outPath = ./.; rev = "abcdef"; } }:
let
  sources = import ./nix/sources.nix;
  pkgs = import ./nix {};

in pkgs.lib.fix (self: {
  inherit (pkgs)
    cardano-cli
    cardano-ping
    kes-rotation
    nginxExplorer
    node-update
    oauth2_proxy
    prometheus-varnish-exporter
    varnish
    varnish-modules;

  forceNewEval = pkgs.writeText "forceNewEval" cardano-ops.rev;

  required = pkgs.releaseTools.aggregate {
    name = "required";
    constituents = with self; [
      forceNewEval
      cardano-cli
      cardano-ping
      kes-rotation
      nginxExplorer
      node-update
      oauth2_proxy
      prometheus-varnish-exporter
      varnish
      varnish-modules
    ];
  };
})
