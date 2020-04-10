{ config, pkgs, ... }:
{
  imports = [
    ../modules/load-client.nix
  ];

  systemd.services.cardano-node.after = [ "ephemeral.service" ];

  # Configure high IOPS on any ec2 node supporting it for cardano-node load client
  systemd.services.ephemeral = {
    wantedBy = [ "multi-user.target" ];
    before = [ "cardano-node.service" "sshd.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    path = with pkgs; [
      coreutils
      e2fsprogs
      gnugrep
      gnused
      gnutar
      kmod
      mdadm
      utillinux
    ];
    script = let
      replacePath = "/var/lib/cardano-node";
    in ''
      #!/run/current-system/sw/bin/bash
      # This script should work on any ec2 instance which has an EBS nvme0n1 root vol and additional
      # non-EBS local nvme[1-9]n1 ephemeral block storage devices, ex: c5, g4, i3, m5, r5, x1, z1.
      set -x
      df | grep -q ${replacePath} && { echo "${replacePath} is pre-mounted, exiting."; exit 0; }
      mapfile -t DEVS < <(find /dev -maxdepth 1 -regextype posix-extended -regex ".*/nvme[1-9]n1")
      [ "''${#DEVS[@]}" -eq "0" ] && { echo "No additional NVME found, exiting."; exit 0; }
      if [ -d ${replacePath} ]; then
        mv ${replacePath} ${replacePath}-backup
      fi
      mkdir -p ${replacePath}
      if [ "''${#DEVS[@]}" -gt "1" ]; then
        mdadm --create --verbose --auto=yes /dev/md0 --level=0 --raid-devices="''${#DEVS[@]}" "''${DEVS[@]}"
        mkfs.ext4 /dev/md0
        mount /dev/md0 ${replacePath}
      elif [ "''${#DEVS[@]}" -eq "1" ]; then
        mkfs.ext4 "''${DEVS[@]}"
        mount "''${DEVS[@]}" ${replacePath}
      fi
      if [ -d ${replacePath}-backup ]; then
        mv ${replacePath}-backup/* ${replacePath}/
      fi
      set +x
    '';
  };

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
