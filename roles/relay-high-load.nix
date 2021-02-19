pkgs:
with pkgs; with lib;
{name, ...}: {

  imports = [
    cardano-ops.roles.relay
  ];

  # Add host and container auto metrics and alarming
  services.custom-metrics.enableNetdata = true;
}
