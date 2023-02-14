self: super: with self; let

  getCardanoNodePackages = src: let
    inherit (import (src + "/nix") { gitrev = src.rev; }) cardanoNodeProject plutus-scripts;
    cardanoNodeHaskellPackages = lib.mapAttrsRecursiveCond (v: !(lib.isDerivation v))
      (path: value:
        if (lib.isAttrs value) then
          lib.recursiveUpdate value
            {
              passthru = {
                profiled = lib.getAttrFromPath path profiledProject.hsPkgs;
                asserted = lib.getAttrFromPath path assertedProject.hsPkgs;
                eventlogged = lib.getAttrFromPath path eventloggedProject.hsPkgs;
              };
            } else value)
      cardanoNodeProject.hsPkgs;
    profiledProject = cardanoNodeProject.appendModule {
      modules = [{
        enableLibraryProfiling = true;
        packages.cardano-node.components.exes.cardano-node.enableProfiling = true;
        packages.tx-generator.components.exes.tx-generator.enableProfiling = true;
        packages.locli.components.exes.locli.enableProfiling = true;
      }];
    };
    assertedProject = cardanoNodeProject.appendModule {
      modules = [{
        packages = lib.genAttrs [
          "ouroboros-consensus"
          "ouroboros-consensus-cardano"
          "ouroboros-consensus-byron"
          "ouroboros-consensus-shelley"
          "ouroboros-network"
          "network-mux"
        ]
          (name: { flags.asserts = true; });
      }];
    };
    eventloggedProject = cardanoNodeProject.appendModule
      {
        modules = [{
          packages = lib.genAttrs [ "cardano-node" ]
            (name: { configureFlags = [ "--ghc-option=-eventlog" ]; });
        }];
      };

    in {
      inherit cardanoNodeHaskellPackages;
      inherit (cardanoNodeHaskellPackages.cardano-cli.components.exes) cardano-cli;
      inherit (cardanoNodeHaskellPackages.cardano-submit-api.components.exes) cardano-submit-api;
      inherit (cardanoNodeHaskellPackages.cardano-node.components.exes) cardano-node;
      inherit (cardanoNodeHaskellPackages.locli.components.exes) locli;
      inherit (cardanoNodeHaskellPackages.tx-generator.components.exes) tx-generator;
      inherit (cardanoNodeHaskellPackages.cardano-tracer.components.exes) cardano-tracer;

      inherit plutus-scripts;

      cardano-node-profiled = cardano-node.passthru.profiled;
      cardano-node-eventlogged = cardano-node.passthru.eventlogged;
      cardano-node-asserted = cardano-node.passthru.asserted;
    };

    cardanoNodePackages = getCardanoNodePackages sourcePaths.cardano-node;

in cardanoNodePackages // {
  inherit getCardanoNodePackages cardanoNodePackages;
  inherit (import (sourcePaths.cardano-db-sync + "/nix") {}) cardanoDbSyncHaskellPackages;
  cardano-node-services-def = (sourcePaths.cardano-node-service or sourcePaths.cardano-node) + "/nix/nixos";
}
