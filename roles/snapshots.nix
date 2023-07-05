pkgs: { name, config, options, ... }:
with pkgs;

let
  getSrc = name: globals.snapshots.${name} or sourcePaths.${name};

  dbSyncPkgs = let s = getSrc "cardano-db-sync"; in import (s + "/nix") { gitrev = s.rev; };
  cardanoNodePackages = getCardanoNodePackages (getSrc "cardano-node");
  inherit (nodeFlake.packages.${system}) cardano-node cardano-cli;

in {
  imports = [
    (cardano-ops.modules.db-sync {
      inherit dbSyncPkgs cardanoNodePackages;
    })
  ];

  # Use sigint for a clean stop signal
  #
  # This will result in success status on the next release after 8.1.1 for SIGINT,
  # whereas SIGTERM will still return 1 despite otherwise clean exit.
  #
  # Until then, temporarily force recognition of RC 1 as success for snapshots automation,
  # as clean service stoppage is expected to return 1.
  #
  # Refs:
  #  https://github.com/input-output-hk/cardano-node/issues/5312
  #  https://github.com/input-output-hk/cardano-node/pull/5356
  systemd.services.cardano-node.serviceConfig.KillSignal = "SIGINT";
  systemd.services.cardano-node.serviceConfig.SuccessExitStatus = "FAILURE";

  # Create a new snapshot every 24h (if not exist alreay):
  services.cardano-db-sync.takeSnapshot = "always";

  # Increase stop timeout to 3h, to allow for snapshot creation on mainnet
  systemd.services.cardano-db-sync.serviceConfig.TimeoutStopSec = lib.mkForce "3h";
}
