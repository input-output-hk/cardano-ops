self: super:
let
  cardano-db-sync-pkgs = import (self.sourcePaths.cardano-db-sync + "/nix") {};
  cardano-explorer-app-pkgs = import self.sourcePaths.cardano-explorer-app;
  cardano-rest-pkgs = import (self.sourcePaths.cardano-rest + "/nix") {};
  cardano-rosetta-pkgs = import (self.sourcePaths.cardano-rosetta + "/nix") {};
  cardanoNodePkgs = import (self.sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
in rec {
  inherit (cardano-db-sync-pkgs) cardanoDbSyncHaskellPackages;
  inherit cardano-explorer-app-pkgs cardano-rest-pkgs cardanoNodePkgs;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.network-mux.components.exes) cardano-ping;
  inherit (cardano-rosetta-pkgs) cardano-rosetta-server;

  cardano-node-eventlogged = cardanoNodePkgs.cardanoNodeEventlogHaskellPackages.cardano-node.components.exes.cardano-node;
}
