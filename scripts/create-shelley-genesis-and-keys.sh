#!/usr/bin/env bash

pwd
ls

exit 1

set -euxo pipefail
mkdir -p keys
cd ${toString ./keys}
cardano-cli shelley genesis create \
            --genesis-dir . \
            --supply ${toString maxSupply} \
            --gen-genesis-keys ${toString nbBFTNodes} \
            --gen-utxo-keys ${toString nbCoreNodes} \
            --start-time `date -u -d "today + 10 minutes" +'%Y-%m-%dT%H:%M:%SZ'` \
            --testnet-magic 42
# Customize the genesis file
#
# We should ensure that:
#
#    10 * securityParam / activeSlotsCoeff <= epochLength
K=10
F=0.1
SLOT_LENGTH=0.2
EPOCH_LENGTH=`perl -E "say ((10 * $K) / $F)"`
# jq will convert the big nunbers to scientific notation, and old versions of nix cannot handle this. Hence we need to use sed.
sed -Ei "s/^([[:blank:]]*\"updateQuorum\":)([[:blank:]]*[^,]*,)$/\1 ${toString nbBFTNodes},/" genesis.json
sed -Ei "s/^([[:blank:]]*\"epochLength\":)([[:blank:]]*[^,]*,)$/\1 $EPOCH_LENGTH,/" genesis.json
sed -Ei "s/^([[:blank:]]*\"slotLength\":)([[:blank:]]*[^,]*,)$/\1 $SLOT_LENGTH,/" genesis.json
sed -Ei "s/^([[:blank:]]*\"securityParam\":)([[:blank:]]*[^,]*)$/\1 $K/" genesis.json
sed -Ei "s/^([[:blank:]]*\"activeSlotsCoeff\":)([[:blank:]]*[^,]*,)$/\1 $F,/" genesis.json

cardano-cli shelley genesis hash --genesis genesis.json > GENHASH
mkdir -p node-keys
cd node-keys
# Create VRF keys for the BFT nodes.
for i in {1..${toString nbBFTNodes}}; do
  ln -sf ../delegate-keys/delegate$i.vrf.skey node-vrf$i.skey
  ln -sf ../delegate-keys/delegate$i.vrf.vkey node-vrf$i.vkey
done
# Create VRF keys for the pool nodes
for i in `seq $((${toString nbBFTNodes}+1)) ${toString nbCoreNodes}`; do
  cardano-cli shelley node key-gen-VRF \
              --verification-key-file node-vrf$i.vkey \
              --signing-key-file node-vrf$i.skey
done
${renew-kes-keys}/bin/new-KES-keys-at-period 0
