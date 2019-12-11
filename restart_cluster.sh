#!/bin/sh

set -xe

# Restart the cluster

## Stop all cardano-nodes (on core machines and on explorer machine as well)
nixops ssh-for-each systemctl stop cardano-node

## Clean up databases for all core nodes (and for node on explorer machine as well)
nixops ssh-for-each -- rm -rf /var/lib/cardano-node/db-shelley-dev-0 /var/lib/cardano-node/db-shelley-dev-1 /var/lib/cardano-node/db-shelley-dev-2

## Stop cardano-explorer-node and postgres on explorer machine
nixops ssh explorer systemctl stop cardano-explorer-node
nixops ssh explorer systemctl stop postgresql

## Clean up explorer's database
nixops ssh explorer -- rm -rf /var/lib/postgresql
## Clean up generator's logs
nixops ssh explorer -- rm -f /tmp/tx-gen\*.json
## Clean up node's logs (on all core machines and on explorer machine as well).
nixops ssh-for-each -- rm -f /var/lib/cardano-node/logs/node-\*.json

## Start postgresql
nixops ssh explorer systemctl start postgresql

## Start all cardano-nodes (on core machines and on explorer machine as well)
nixops ssh-for-each systemctl start cardano-node

## Start cardano-explorer-node
nixops ssh explorer systemctl start cardano-explorer-node
