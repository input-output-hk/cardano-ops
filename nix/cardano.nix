self: super: with self; {
  cardanoNodePkgs = import (sourcePaths.cardano-node + "/nix") { gitrev = self.sourcePaths.cardano-node.rev; };
  cardanoNodeServicePkgs = import (sourcePaths.cardano-node-service + "/nix") { gitrev = self.sourcePaths.cardano-node-service.rev; };
  ouroboros-network-pkgs = import (sourcePaths.ouroboros-network + "/nix") {};

  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-submit-api.components.exes) cardano-submit-api;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
  inherit ((if (sourcePaths ? ouroboros-network)
    then ouroboros-network-pkgs.ouroborosNetworkHaskellPackages
    else cardanoNodePkgs.cardanoNodeHaskellPackages).network-mux.components.exes) cardano-ping;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.locli.components.exes) locli;
  inherit (cardanoNodePkgs.cardanoNodeHaskellPackages.tx-generator.components.exes) tx-generator;

  cardano-node-eventlogged = cardanoNodePkgs.cardanoNodeEventlogHaskellPackages.cardano-node.components.exes.cardano-node;

  cardano-node-services-def = (sourcePaths.cardano-node-service or sourcePaths.cardano-node) + "/nix/nixos";
}
