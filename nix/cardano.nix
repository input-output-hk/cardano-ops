self: super:
let
  cardano-sl-pkgs = import self.sourcePaths.cardano-sl {
    gitrev = self.sourcePaths.cardano-sl.rev;
  };
in {
  inherit ((import self.sourcePaths.cardano-node {}).haskellPackages.cardano-cli.components.exes) cardano-cli;

  cardano-node-legacy = cardano-sl-pkgs.nix-tools.cexes.cardano-sl-node.cardano-node-simple;
  cardano-node-legacy-config = cardano-sl-pkgs.cardanoConfig; # FIXME: use iohk-nix
}
