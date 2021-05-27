self: super:
let
  cardano-db-sync-pkgs = import (self.sourcePaths.cardano-db-sync + "/nix") {};
  cardano-db-sync-pkgs-old = import (self.sourcePaths.cardano-db-sync-old + "/nix") {};
  cardano-explorer-app-pkgs = import self.sourcePaths.cardano-explorer-app;
  cardano-rosetta-pkgs = import (self.sourcePaths.cardano-rosetta + "/nix") {};
  cardanoNodePkgs = import (self.sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
in rec {
  inherit (cardano-db-sync-pkgs) cardanoDbSyncHaskellPackages;
  cardanoDbSyncHaskellPackagesOld =  cardano-db-sync-pkgs-old.cardanoDbSyncHaskellPackages;
  inherit cardano-explorer-app-pkgs cardanoNodePkgs;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-submit-api.components.exes) cardano-submit-api;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.network-mux.components.exes) cardano-ping;
  inherit (cardano-rosetta-pkgs) cardano-rosetta-server;

  cardano-node-eventlogged = cardanoNodePkgs.cardanoNodeEventlogHaskellPackages.cardano-node.components.exes.cardano-node;

  cardano-node-services-def = (self.sourcePaths.cardano-node-service
    or self.sourcePaths.cardano-node) + "/nix/nixos";
}
