#!/usr/bin/env bash
#
# Create the genesis file for the Shelley testnet, and the different keys that
# the nodes use.
#
# Keys and genesis files are placed in the `keys` directory.
#
# This script requires the following environment variables to be defined:
#
# - BFT_NODES: names of the BFT nodes
# - POOL_NODES: names of the stake pool nodes
# - K: the security parameter for the network
# - F: the active slot coefficient
# - MAX_SUPPLY: total lovelace supply
#
set -euo pipefail

[ -z ${BFT_NODES+x} ] && (echo "Environment variable BFT_NODES must be defined"; exit 1)
[ -z ${POOL_NODES+x} ] && (echo "Environment variable POOL_NODES must be defined"; exit 1)
[ -z ${K+x} ] && (echo "Environment variable K must be defined"; exit 1)
[ -z ${F+x} ] && (echo "Environment variable F must be defined"; exit 1)
[ -z ${MAX_SUPPLY+x} ] && (echo "Environment variable MAX_SUPPLY must be defined"; exit 1)

# Variables BFT_NODES and POOL_NODES should be strings containing the nodes
# names separated by spaces. At the moment it does not seem to be a way of
# converting nix lists into bash arrays, so we need to perfom the string to
# array conversion here:
BFT_NODES=($BFT_NODES)
POOL_NODES=($POOL_NODES)
TOTAL_NODES=$((${#BFT_NODES[@]}+${#POOL_NODES[@]}))

mkdir -p keys
cd keys

cardano-cli shelley genesis create \
            --genesis-dir . \
            --supply $MAX_SUPPLY \
            --gen-genesis-keys ${#BFT_NODES[@]} \
            --gen-utxo-keys $TOTAL_NODES \
            --start-time `date -u -d "today + 10 minutes" +'%Y-%m-%dT%H:%M:%SZ'` \
            --testnet-magic 42

# Customize the genesis file
#
# The epoch length must satisfy:
#
#    10 * securityParam / activeSlotsCoeff <= epochLength
#
# so we set the epoch length to exactly the value of the left hand side of the
# inequality.
EPOCH_LENGTH=`perl -E "say ((10 * $K) / $F)"`
# jq will convert the big nunbers to scientific notation, and old versions of
# nix cannot handle this. Hence we need to use sed.
sed -Ei "s/^([[:blank:]]*\"updateQuorum\":)([[:blank:]]*[^,]*,)$/\1 ${#BFT_NODES[@]},/" genesis.json
sed -Ei "s/^([[:blank:]]*\"epochLength\":)([[:blank:]]*[^,]*,)$/\1 $EPOCH_LENGTH,/" genesis.json
sed -Ei "s/^([[:blank:]]*\"slotLength\":)([[:blank:]]*[^,]*,)$/\1 $SLOT_LENGTH,/" genesis.json
sed -Ei "s/^([[:blank:]]*\"securityParam\":)([[:blank:]]*[^,]*)$/\1 $K/" genesis.json
sed -Ei "s/^([[:blank:]]*\"activeSlotsCoeff\":)([[:blank:]]*[^,]*,)$/\1 $F,/" genesis.json

cardano-cli shelley genesis hash --genesis genesis.json > GENHASH
mkdir -p node-keys
cd node-keys
# Create VRF keys for the BFT nodes.
for i in `seq 1 ${#BFT_NODES[@]}`; do
  ln -sf ../delegate-keys/delegate$i.vrf.skey node-vrf$i.skey
  ln -sf ../delegate-keys/delegate$i.vrf.vkey node-vrf$i.vkey
done

# Create VRF keys for the pool nodes
for i in `seq $((${#BFT_NODES[@]}+1)) $TOTAL_NODES`; do
  cardano-cli shelley node key-gen-VRF \
              --verification-key-file node-vrf$i.vkey \
              --signing-key-file node-vrf$i.skey
done

# ${renew-kes-keys}/bin/new-KES-keys-at-period 0
