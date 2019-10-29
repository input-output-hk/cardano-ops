self: super:
let
  cardano-sl-pkgs = import self.sources.cardano-sl {
    gitrev = self.sources.cardano-sl.rev;
  };
in {

  inherit ((import self.sources.cardano-node {}).nix-tools.cexes.cardano-node) cardano-cli;


  cardano-node-legacy = cardano-sl-pkgs.nix-tools.cexes.cardano-sl-node.cardano-node-simple;
  cardano-node-legacy-config = cardano-sl-pkgs.cardanoConfig; # FIXME: use iohk-nix

}
