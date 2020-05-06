self: super:
let
  cardano-benchmarking-pkgs = import self.sourcePaths.cardano-benchmarking {
    gitrev = self.sourcePaths.cardano-benchmarking.rev;
  };
in {
  inherit ((import self.sourcePaths.cardano-benchmarking {}).haskellPackages) cardano-tx-generator;
}
