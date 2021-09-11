#!/usr/bin/env bash
#
# This script assumes:
#
# - the kes period is passed as the first argument,
# - the number of bft nodes is passed as second argument,
# - the total number of nodes is passed as third argument,
# - the node keys are in a keys/node-keys directory, which must exist.
#
set -euo pipefail

cd "$(dirname "$0")/.."

[ -z ${1+x} ] && (echo "Missing KES period (must be passed as first argument)"; exit 1);

PERIOD=$1

cd keys/node-keys

# Generate new KES key pairs
for i in `seq 1 $NB_CORE_NODES`; do
  cardano-cli node key-gen-KES \
              --verification-key-file node-kes$i.vkey.new \
              --signing-key-file node-kes$i.skey.new
done

# Genereate an operational certificate for the BFT nodes, using the delegate
# keys as cold signing key.
for i in `seq 1 $NB_BFT_NODES`; do
  cardano-cli node issue-op-cert \
              --hot-kes-verification-key-file node-kes$i.vkey.new \
              --cold-signing-key-file ../delegate-keys/delegate$i.skey \
              --operational-certificate-issue-counter ../delegate-keys/delegate$i.counter \
              --kes-period $PERIOD \
              --out-file node$i.opcert
done
# Genereate an operational certificate for the staking pool nodes, using the pool
# keys as cold signing key.
for i in `seq $((NB_BFT_NODES+1)) $NB_CORE_NODES`; do
  cardano-cli node issue-op-cert \
              --hot-kes-verification-key-file node-kes$i.vkey.new \
              --cold-signing-key-file ../pools/cold$((i - $NB_BFT_NODES)).skey \
              --operational-certificate-issue-counter ../pools/opcert$((i - $NB_BFT_NODES)).counter \
              --kes-period $PERIOD \
              --out-file node$i.opcert
done

# Replace existing KES key pair with new (because above commands succeeded)
for i in `seq 1 $NB_CORE_NODES`; do
  mv node-kes$i.vkey.new node-kes$i.vkey
  mv node-kes$i.skey.new node-kes$i.skey
done
