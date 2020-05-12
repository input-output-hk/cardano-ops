{ pkgs, ... }@args:
with pkgs;
iohk-ops-lib.physical.aws.security-groups.allow-all-to-tcp-port
  "cardano" globals.cardanoNodePort args
