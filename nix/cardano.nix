self: super:
let
  cardano-db-sync-pkgs = import self.sourcePaths.cardano-db-sync {
    gitrev = self.sourcePaths.cardano-db-sync.rev;
  };
  cardano-explorer-app-pkgs = import self.sourcePaths.cardano-explorer-app {};
  cardano-rest-pkgs = import (self.sourcePaths.cardano-rest + "/nix") {};
  cardanoNodePkgs = import (self.sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
in rec {
  inherit cardano-db-sync-pkgs cardano-explorer-app-pkgs cardano-rest-pkgs cardanoNodePkgs;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
}
