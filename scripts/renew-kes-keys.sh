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

[ -z ${1+x} ] && (echo "Missing KES period (must be passed as first argument)"; exit 1);
[ -z ${2+x} ] && (echo "Missing number of BFT nodes (must be passed as second argument)"; exit 1);
[ -z ${3+x} ] && (echo "Missing total number of nodes (must be passed as third argument)"; exit 1);

PERIOD=$1
NR_BFT_NODES=$2
TOTAL_NODES=$3
cd keys/node-keys

# Generate a KES key pair
for i in `seq 1 $TOTAL_NODES`; do
  cardano-cli shelley node key-gen-KES \
              --verification-key-file node-kes$i.vkey \
              --signing-key-file node-kes$i.skey
done
# Genereate an operational certificate for the BFT nodes, using the delegate
# keys as cold signing key.
for i in `seq 1 $NR_BFT_NODES`; do
  cardano-cli shelley node issue-op-cert \
              --hot-kes-verification-key-file node-kes$i.vkey \
              --cold-signing-key-file ../delegate-keys/delegate$i.skey \
              --operational-certificate-issue-counter ../delegate-keys/delegate$i.counter \
              --kes-period $PERIOD \
              --out-file node$i.opcert
done
# For the pool nodes we need to generate the cold keys and the cold counter.
for i in `seq $((NR_BFT_NODES+1)) $TOTAL_NODES`; do
  cardano-cli shelley node key-gen \
      --cold-verification-key-file cold$i.vkey \
      --cold-signing-key-file cold$i.skey \
      --operational-certificate-issue-counter-file cold$i.counter
  cardano-cli shelley node issue-op-cert \
              --hot-kes-verification-key-file node-kes$i.vkey \
              --cold-signing-key-file cold$i.skey \
              --operational-certificate-issue-counter cold$i.counter \
              --kes-period $PERIOD \
              --out-file node$i.opcert
done
