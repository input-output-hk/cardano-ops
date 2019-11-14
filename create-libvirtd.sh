#!/usr/bin/env bash

set -euxo pipefail

# https://nixos.org/nixops/manual/#idm140737322394336
# Needed for libvirtd:
#
# virtualisation.libvirtd.enable = true;
# networking.firewall.checkReversePath = false;

# See also: https://github.com/simon3z/virt-deploy/issues/8#issuecomment-73111541

if [ ! -d /var/lib/libvirt/images ]; then
  sudo mkdir -p /var/lib/libvirt/images
  sudo chgrp libvirtd /var/lib/libvirt/images
  sudo chmod g+w /var/lib/libvirt/images
fi

# Credential setup
if [ ! -f ./static/graylog-creds.nix ]; then
  nix-shell -A gen-graylog-creds
fi

nixops destroy || true
nixops delete || true
nixops create ./deployments/cardano-libvirtd.nix -I nixpkgs=./nix
nixops deploy --show-trace --build-only
