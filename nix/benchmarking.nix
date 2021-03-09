self: super:
let
  cardano-benchmarking-pkgs = import self.sourcePaths.cardano-benchmarking {
    gitrev = self.sourcePaths.cardano-benchmarking.rev;
  };
in {
  inherit (cardano-benchmarking-pkgs.haskellPackages) cardano-tx-generator locli;
}
