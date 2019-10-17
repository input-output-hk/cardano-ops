self: super: {

  inherit ((import self.sources.cardano-node {}).nix-tools.cexes.cardano-node) cardano-cli;

}
