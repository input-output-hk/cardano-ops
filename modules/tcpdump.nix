{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tcpdump;
in {
  options.services.tcpdump = {
    enable = lib.mkEnableOption "tcpdump capture and upload";

    bucketName = lib.mkOption {
      type = lib.types.str;
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [3001 3002];
    };

    rotateSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60 * 10;
    };

    s3ExpirationDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 7;
    };
  };

  config = lib.mkIf cfg.enable {
    deployment.keys.pcap-upload = {
      keyFile = ../static/pcap-upload;
      destDir = "/var/lib/keys";
    };

    systemd.services = (
      lib.listToAttrs (map (
          port: {
            name = "tcpdump-${toString port}";
            value = {
              description = "capture packets on port ${toString port}";
              wantedBy = ["multi-user.target"];
              after = ["network-online.target"];
              startLimitIntervalSec = 10;
              startLimitBurst = 10;
              serviceConfig = {
                Restart = "always";
                StateDirectory = "tcpdump";
                WorkingDirectory = "/var/lib/tcpdump";
              };
              path = [pkgs.tcpdump pkgs.inetutils];

              script = ''
                set -exuo pipefail

                dir="$(hostname)_${toString port}"
                mkdir -p "$dir"
                cd "$dir"

                tcpdump \
                  -i any \
                  -w '%Y-%m-%d_%H:%M:%S.pcap' \
                  -G ${toString cfg.rotateSeconds} \
                  -n 'port ${toString port}'
              '';
            };
          }
        )
        cfg.ports)
      // {
        tcpdump-upload = {
          wantedBy = ["multi-user.target"];
          after = ["tcpdump.service"];
          startLimitIntervalSec = 10;
          startLimitBurst = 10;
          serviceConfig = {
            Restart = "always";
            StateDirectory = "tcpdump";
            WorkingDirectory = "/var/lib/tcpdump";
          };
          path = [pkgs.awscli2 pkgs.fd];
          environment.HOME = "/var/lib/tcpdump";

          # NOTE: the format in 's3://${cfg.bucketName}/{//}/{/}' may be subject to change in future versions of `fd`.
          script = ''
            set -exuo pipefail

            mkdir -p .aws
            cp /var/lib/keys/pcap-upload .aws/credentials

            while true; do
              fd -e pcap --changed-before='${toString (cfg.rotateSeconds * 2)} seconds' -j 1 -x \
                aws s3 mv '{}' 's3://${cfg.bucketName}/{//}/{/}'
              sleep 60
            done
          '';
        };
      }
    );
  };
}
