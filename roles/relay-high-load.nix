pkgs:
with pkgs; with lib;
{name, ...}: {

  imports = [
    cardano-ops.roles.relay
  ];

  # Performance testing temporary changes; suitable for vertical scaling with
  # t3.xlarge (16 GB RAM, 4 vCPU, 30 GB gp2)
  systemd.services.cardano-node.serviceConfig.MemoryMax = lib.mkForce "14G";

  # Similarly, increase the max gc memory -- modify `-M` param
  # https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/runtime_control.html
  services.cardano-node.rtsArgs = lib.mkForce (if (name == "rel-a-2") then
          [ "-N2" "-A16m" "-qg" "-qb" "-M10G" ]
        else if (name == "rel-a-3") then
          [ "-N1" "-A1m" "-M10G" ]
        else if (name == "rel-a-4") then
          [ "-N2" "-A16m" "-M10G" ]
        else [ "-N4" "-A10m" "-qg" "-qb" "-M10G" ]);

  systemd.services.cardano-node.serviceConfig.LimitNOFILE = "65535";

  # Add host and container auto metrics and alarming
  services.custom-metrics.enableNetdata = true;
}
