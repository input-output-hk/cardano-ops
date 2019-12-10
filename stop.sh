#!/bin/sh

set -ex

nixops ssh-for-each systemctl stop cardano-node
nixops ssh explorer systemctl stop cardano-explorer-node
nixops ssh explorer systemctl stop postgresql


