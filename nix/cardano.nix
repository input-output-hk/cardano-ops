self: super:
let
  cardano-db-sync-pkgs = import (self.sourcePaths.cardano-db-sync + "/nix") {};
  cardano-explorer-app-pkgs = import self.sourcePaths.cardano-explorer-app;
  cardano-rosetta-pkgs = import (self.sourcePaths.cardano-rosetta + "/nix") {};
  cardanoNodePkgs = import (self.sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
  cardanoNodeServicePkgs = import (self.sourcePaths.cardano-node-service + "/nix") { gitrev = self.sourcePaths.cardano-node-service.rev; };
in rec {
  inherit cardanoNodeServicePkgs;
  inherit (cardano-db-sync-pkgs) cardanoDbSyncHaskellPackages;
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
