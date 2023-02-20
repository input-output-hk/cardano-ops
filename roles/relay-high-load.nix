pkgs:
with pkgs; with lib;
{name, config, ...}: let
 cfg = config.services.cardano-node;
in {

  imports = [
    cardano-ops.roles.relay
  ];

  # Add host and container auto metrics and alarming
  services.custom-metrics.enableNetdata = true;

  services.cardano-node.extraNodeConfig = {
    AcceptedConnectionsLimit = {
      # Ensure limits are above our alerts threshold:
      hardLimit = topology-lib.roundToInt
        (globals.alertTcpCrit / cfg.instances * 1.05);
      softLimit = topology-lib.roundToInt
        (globals.alertTcpHigh / cfg.instances * 1.05);
      delay = 5;
    };
  };
}
