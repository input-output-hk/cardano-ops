pkgs: with pkgs; with lib;
{

  imports = [
    cardano-ops.modules.base-service
  ];

  # Performance testing temporary changes; suitable for vertical scaling with
  # t3.xlarge (16 GB RAM, 4 vCPU, 30 GB gp2)
  systemd.services.cardano-node.serviceConfig.MemoryMax = lib.mkForce "14G";

  # Similarly, increase the max gc memory -- modify `-M` param
  # https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/runtime_control.html
  services.cardano-node.extraArgs = lib.mkForce [ "+RTS" "-N4" "-A10m" "-qg" "-qb" "-M10G" "-RTS" ];

  systemd.services.cardano-node.serviceConfig.LimitNOFILE = "65535";

  # Add host and container auto metrics and alarming
  services.netdata = {
    enable = true;
    config = {
      global = {
        "default port" = "19999";
        "bind to" = "*";
        "history" = "86400";
        "error log" = "syslog";
        "debug log" = "syslog";
      };
    };
  };
}
