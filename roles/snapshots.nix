pkgs: { name, config, options, ... }:
with pkgs;

let
  getSrc = name: globals.snapshots.${name} or sourcePaths.${name};

  dbSyncPkgs = let s = getSrc "cardano-db-sync"; in import (s + "/nix") { gitrev = s.rev; };
  cardanoNodePkgs = getCardanoNodePackages (getSrc "cardano-node");
  inherit (nodeFlake.packages.${system}) cardano-node cardano-cli;

in {
  imports = [
    (cardano-ops.modules.db-sync {
      inherit dbSyncPkgs cardanoNodePkgs;
    })
  ];


  # Create a new snapshot every 24h (if not exist alreay):
  services.cardano-db-sync.takeSnapshot = "always";
}
