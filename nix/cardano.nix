self: super:
let
  cardano-sl-pkgs = import self.sourcePaths.cardano-sl {
    gitrev = self.sourcePaths.cardano-sl.rev;
  };
  cardano-db-sync-pkgs = import self.sourcePaths.cardano-db-sync {
    gitrev = self.sourcePaths.cardano-db-sync.rev;
  };
  cardano-byron-proxy-pkgs = import self.sourcePaths.cardano-byron-proxy {
    gitrev = self.sourcePaths.cardano-byron-proxy.rev;
  };
  cardano-explorer-app-pkgs = import self.sourcePaths.cardano-explorer-app {};
  cardano-rest-pkgs = import (self.sourcePaths.cardano-rest + "/nix") {};
  cardanoNodePkgs = import (self.sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
in rec {
  inherit cardano-sl-pkgs cardano-db-sync-pkgs cardano-byron-proxy-pkgs cardano-explorer-app-pkgs
    cardano-rest-pkgs cardanoNodePkgs;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
  cardano-node-legacy = cardano-sl-pkgs.nix-tools.cexes.cardano-sl-node.cardano-node-simple;
  cardano-node-legacy-config = cardano-sl-pkgs.cardanoConfig; # FIXME: use iohk-nix
}
