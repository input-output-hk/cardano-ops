#!/usr/bin/env bash
#
# NOTE: This is an updated WIP of the scripts/create-genesis-and-keys.sh script.
#       The old version of the script appears to no longer work, but until this
#       replacement script does fully work, the old one will be preserved.
#
# Create the genesis file for the Shelley testnet, and the different keys that
# the nodes use.
#
# Keys and genesis files are placed in the `keys` directory.
#
# This script requires the following environment variables to be defined:
#
# - NB_BFT_NODES: number of BFT nodes
# - NB_POOL_NODES: number of staking pool nodes
# - K: the security parameter for the network
# - F: the active slot coefficient
# - MAX_SUPPLY: total lovelace supply
#
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_NAME=$(nix eval --raw --impure --expr '(import ./nix {}).globals.environmentName')
[ -z "${ENV_NAME:-}" ] && ENV_NAME=localTest
[ -z "${NB_BFT_NODES:-}" ] && (echo "Environment variable NB_BFT_NODES must be defined"; exit 1)
[ -z "${NB_POOL_NODES:-}" ] && (echo "Environment variable NB_POOL_NODES must be defined"; exit 1)
[ -z "${K:-}" ] && (echo "Environment variable K must be defined"; exit 1)
[ -z "${F:-}" ] && (echo "Environment variable F must be defined"; exit 1)
[ -z "${MAX_SUPPLY:-}" ] && (echo "Environment variable MAX_SUPPLY must be defined"; exit 1)
[ -z "${SLOT_LENGTH:-}" ] && (echo "Environment variable SLOT_LENGTH must be defined"; exit 1)
[ -z "${NETWORK_MAGIC:-}" ] && (echo "Environment variable NETWORK_MAGIC must be defined"; exit 1)

export NB_CORE_NODES=$((NB_BFT_NODES + NB_POOL_NODES))
export DELAY="${DELAY:-30}"
export UTXO_KEYS="${UTXO_KEYS:-1}"
export DPARAM="${DPARAM:-$(awk "BEGIN{print 1.0 - 1.0 * $NB_POOL_NODES / $NB_CORE_NODES}")}"

# shellcheck disable=SC2153
echo "Generating new genesis and keys using following environments variables:

  NB_BFT_NODES=$NB_BFT_NODES (number of bft core nodes)
  NB_POOL_NODES=$NB_POOL_NODES (number of staking pool nodes)
  UTXO_KEYS=$UTXO_KEYS (number of rich keys)
  K=$K (Security parameter)
  F=$F (Active slots coefficient)
  MAX_SUPPLY=$MAX_SUPPLY (Max Lovelace supply)
  SLOT_LENGTH=$SLOT_LENGTH
  NETWORK_MAGIC=$NETWORK_MAGIC
  DELAY=$DELAY (delay in minutes before genesis systemStart)
  DPARAM=$DPARAM (decentralization parameter)
  DOMAIN=$DOMAIN
  RELAYS=$RELAYS
"

mkdir -p keys
cd keys

IOHK_NIX=$(nix eval --raw --impure --expr '(builtins.getFlake github:input-output-hk/iohk-nix).outPath')
TEMPLATE_DIR="$IOHK_NIX/cardano-lib/testnet-template"

for i in byron shelley alonzo conway; do
  cp "$TEMPLATE_DIR/$i.json" ./genesis.$i.spec.json
  chmod +w "genesis.$i.spec.json"
done

START_TIME=$(date -u -d "today + $DELAY minutes" +'%Y-%m-%dT%H:%M:%SZ')
export START_TIME

# Customize the genesis template file
#
# The epoch length must satisfy:
#
#    10 * securityParam / activeSlotsCoeff <= epochLength
#
# So we set the epoch length to exactly the value of the left hand side of the
# inequality.
EPOCH_LENGTH=$(perl -E "say ((10 * $K) / $F)")

if [ "$NB_BFT_NODES" -lt 1 ]; then
  GENKEYS=1
else
  GENKEYS=$NB_BFT_NODES
fi

# jq will convert the big numbers to scientific notation, and old versions of
# nix cannot handle this. Hence we need to use sed.
sed -Ei "s/^([[:blank:]]*\"updateQuorum\":)([[:blank:]]*[^,]*,)$/\1 $GENKEYS,/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"epochLength\":)([[:blank:]]*[^,]*,)$/\1 $EPOCH_LENGTH,/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"slotLength\":)([[:blank:]]*[^,]*,)$/\1 $SLOT_LENGTH,/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"securityParam\":)([[:blank:]]*[^,]*)$/\1 $K/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"activeSlotsCoeff\":)([[:blank:]]*[^,]*,)$/\1 $F,/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"networkMagic\":)([[:blank:]]*[^,]*,)$/\1 $NETWORK_MAGIC,/" genesis.shelley.spec.json
sed -Ei "s/^([[:blank:]]*\"decentralisationParam\":)([[:blank:]]*[^,]*)$/\1 $DPARAM/" genesis.shelley.spec.json

bash -euc 'cardano-cli genesis create-staked \
  --genesis-dir . \
  --supply $(((2 * MAX_SUPPLY) / 3 - (NB_POOL_NODES * MAX_SUPPLY / 500))) \
  --supply-delegated $((NB_POOL_NODES * MAX_SUPPLY / 500)) \
  --gen-genesis-keys "$NB_BFT_NODES" \
  --gen-pools "$NB_POOL_NODES" \
  --gen-stake-delegs "$NB_POOL_NODES" \
  --gen-utxo-keys "$UTXO_KEYS" \
  --start-time "$START_TIME" \
  --testnet-magic "$NETWORK_MAGIC"'

sed -Ei "s/^([[:blank:]]*\"maxLovelaceSupply\":)([[:blank:]]*[^,]*,)$/\1 $MAX_SUPPLY,/" genesis.json
jq '.initialFunds = {} | del(.staking)' genesis.json > genesis.json.new
mv genesis.json.new genesis.json

cardano-cli genesis hash --genesis genesis.json > GENHASH
cardano-cli genesis hash --genesis genesis.alonzo.json > ALONZOGENHASH
cardano-cli genesis hash --genesis genesis.conway.json > CONWAYGENHASH

for i in $(seq 1 "$NB_POOL_NODES"); do
  # Generate delegator stake keys
  cardano-cli stake-address key-gen \
    --verification-key-file "stake-delegator-keys/staking$i.vkey" \
    --signing-key-file "stake-delegator-keys/staking$i.skey"

  # Generate delegator payment keys
  cardano-cli address key-gen \
    --verification-key-file "stake-delegator-keys/payment$i.vkey" \
    --signing-key-file "stake-delegator-keys/payment$i.skey"

  # Generate delegator stake registration cert
  cardano-cli stake-address registration-certificate \
    --stake-verification-key-file "stake-delegator-keys/staking$i.vkey" \
    --out-file "stake-delegator-keys/staking$i.reg.cert"

  # Generate pool stake registration cert
  cardano-cli stake-address registration-certificate \
    --stake-verification-key-file "pools/staking-reward$i.vkey" \
    --out-file "pools/staking-reward$i.reg.cert"

  # Generate delegator stake delegation cert
  cardano-cli stake-address delegation-certificate \
    --stake-verification-key-file "stake-delegator-keys/staking$i.vkey"  \
    --cold-verification-key-file "pools/cold$i.vkey" \
    --out-file "stake-delegator-keys/staking$i.deleg.cert"

  # Generate delegator staking payment address
  cardano-cli address build \
    --payment-verification-key-file "stake-delegator-keys/payment$i.vkey" \
    --stake-verification-key-file "stake-delegator-keys/staking$i.vkey" \
    --out-file "stake-delegator-keys/staking$i.addr" \
    --testnet-magic "$NETWORK_MAGIC"

  if [ -f "../static/pool-metadata/p/$i.json" ]; then
    METADATA="../static/pool-metadata/p/$i.json"
    TICKER=$(jq -r '.ticker' < "$METADATA")
    METADATA_HASH=$(cardano-cli stake-pool metadata-hash --pool-metadata-file "$METADATA")
  else
    TICKER="LTP$i"
    METADATA="{\"name\":\"$ENV_NAME-$i\",\"description\":\"localTest\",\"ticker\":\"$TICKER\",\"homepage\":\"https://monitoring.$DOMAIN\"}";
    METADATA_HASH=$(cardano-cli stake-pool metadata-hash --pool-metadata-file <(echo "$METADATA"))
  fi

  RELAY=$(echo "$TICKER" | tr '[:upper:]' '[:lower:]').$RELAYS
  METADATA_URL="https://monitoring.$DOMAIN/p/$i.json"

  # Stake pool registration cert
  bash -euc "cardano-cli stake-pool registration-certificate \
    --testnet-magic \"$NETWORK_MAGIC\" \
    --pool-pledge $((MAX_SUPPLY / 500)) \
    --pool-cost $((1000000000 - (i * 500000000 / NB_POOL_NODES))) --pool-margin \"0.0$i\" \
    --cold-verification-key-file \"pools/cold$i.vkey\" \
    --vrf-verification-key-file \"pools/vrf$i.vkey\" \
    --reward-account-verification-key-file \"pools/staking-reward$i.vkey\" \
    --pool-owner-stake-verification-key-file \"stake-delegator-keys/staking$i.vkey\" \
    --out-file \"pools/pool$i.reg.cert\" \
    --single-host-pool-relay \"$RELAY\" \
    --pool-relay-port 3001 \
    --metadata-url \"$METADATA_URL\" \
    --metadata-hash \"$METADATA_HASH\""
done

for i in $(seq 1 "$UTXO_KEYS"); do
  cardano-cli address build \
    --payment-verification-key-file "utxo-keys/utxo$i.vkey" \
    --out-file "utxo-keys/utxo$i.addr" \
    --testnet-magic "$NETWORK_MAGIC"
done

if [ -f "$BYRON_GENESIS_PATH" ]; then
  jq '.blockVersionData' \
  < "$BYRON_GENESIS_PATH" \
  > ./byron-genesis.spec.json

  sed -Ei "s/^([[:blank:]]*\"slotLength\":)([[:blank:]]*[^,]*,)$/\1 $SLOT_LENGTH,/" genesis.json

  rm -rf byron

  # shellcheck disable=SC1001
  bash -euc "cardano-cli byron genesis genesis \
    --protocol-magic \"$NETWORK_MAGIC\" \
    --start-time \"$(date +\%s -d "$START_TIME")\" \
    --k \"$K\" \
    --n-poor-addresses 0 \
    --n-delegate-addresses \"$NB_BFT_NODES\" \
    --total-balance \"$MAX_SUPPLY\" \
    --delegate-share \"$(awk "BEGIN{print 2 / 3}")\" \
    --avvm-entry-count 0 \
    --avvm-entry-balance 0 \
    --protocol-parameters-file genesis.byron.spec.json \
    --genesis-output-dir byron"

  cardano-cli byron genesis print-genesis-hash --genesis-json byron/genesis.json > byron/GENHASH

  # Create keys, addresses and transactions to withdraw the initial UTxO into
  # regular addresses.
  cardano-cli byron key keygen \
    --secret byron/rich.key \

  cardano-cli byron key signing-key-address \
    --testnet-magic "$NETWORK_MAGIC" \
    --secret byron/rich.key > byron/rich.addr

  cardano-cli key convert-byron-key \
    --byron-signing-key-file byron/rich.key \
    --out-file byron/rich-converted.key \
    --byron-payment-key-type

  for N in $(seq 1 "$NB_BFT_NODES"); do
    cardano-cli byron key signing-key-address \
      --testnet-magic "$NETWORK_MAGIC" \
      --secret "byron/genesis-keys.00$((N - 1)).key" > "byron/genesis-address-00$((N - 1))"

    rm -f "tx-convert-byron-funds-$N.tx"

    cardano-cli byron transaction issue-genesis-utxo-expenditure \
      --genesis-json byron/genesis.json \
      --testnet-magic "$NETWORK_MAGIC" \
      --tx "tx-convert-byron-funds-$N.tx" \
      --wallet-key "byron/delegate-keys.00$((N - 1)).key" \
      --rich-addr-from "$(head -n 1 byron/genesis-address-00$((N - 1)))" \
      --txout "(\"$(head -n 1 byron/rich.addr)\", $((MAX_SUPPLY * 2 / (NB_BFT_NODES * 3))))"
  done

  # shellcheck disable=SC2046
  cardano-cli transaction build-raw \
    --shelley-era \
    --ttl 10000000000 \
    --fee $((100000 + 100000 * NB_POOL_NODES)) \
    $(for i in $(seq 1 "$NB_BFT_NODES"); do
      echo " --tx-in $(cardano-cli byron transaction txid --tx "tx-convert-byron-funds-$i.tx")#0"
    done) \
    $(for i in $(seq 1 "$UTXO_KEYS"); do
      echo " --tx-out $(cat "utxo-keys/utxo$i.addr")+$((((2 * MAX_SUPPLY) / 3  - (100000 + 504000000 + MAX_SUPPLY / 500) * NB_POOL_NODES - 100000) / UTXO_KEYS))"
    done) \
    $(for i in $(seq 1 "$NB_POOL_NODES"); do
      echo " --tx-out $(cat "stake-delegator-keys/staking$i.addr")+$((MAX_SUPPLY / 500))"
      echo " --certificate-file pools/staking-reward$i.reg.cert"
      echo " --certificate-file pools/pool$i.reg.cert"
      echo " --certificate-file stake-delegator-keys/staking$i.reg.cert"
      echo " --certificate-file stake-delegator-keys/staking$i.deleg.cert"
    done) \
    --out-file tx-setup-pools-utxos.txbody

  # shellcheck disable=SC2046
  cardano-cli transaction sign \
    --signing-key-file byron/rich-converted.key \
    $(for i in $(seq 1 "$NB_POOL_NODES"); do
      echo " --signing-key-file stake-delegator-keys/payment$i.skey"
      echo " --signing-key-file stake-delegator-keys/staking$i.skey"
      echo " --signing-key-file pools/staking-reward$i.skey"
      echo " --signing-key-file pools/cold$i.skey"
    done) \
    --testnet-magic "$NETWORK_MAGIC" \
    --tx-body-file tx-setup-pools-utxos.txbody \
    --out-file tx-setup-pools-utxos.tx
fi

echo
echo 'Make sure to submit keys/tx-convert-byron-funds-*.tx transactions during byron era (epoch 0).'
echo 'Then submit keys/tx-setup-pools-utxos.tx during shelley era. (use: TestShelleyHardForkAtEpoch = 1;)'

mkdir -p node-keys
cd node-keys

# Link VRF keys for the BFT nodes.
for i in $(seq 1 "$NB_BFT_NODES"); do
  ln -sf "../delegate-keys/delegate$i.vrf.skey" "node-vrf$i.skey"
  ln -sf "../delegate-keys/delegate$i.kes.skey" "node-kes$i.skey"
  ln -sf "../delegate-keys/opcert$i.cert" "node$i.opcert"
done

# Link VRF keys for the staking pool nodes.
for p in $(seq 1 "$NB_POOL_NODES"); do
  i=$((NB_BFT_NODES+p))
  ln -sf "../pools/vrf$p.skey" "node-vrf$i.skey"
  ln -sf "../pools/vrf$p.vkey" "node-vrf$i.vkey"
  ln -sf "../pools/kes$p.skey" "node-kes$i.skey"
  ln -sf "../pools/opcert$p.cert" "node$i.opcert"
done

mkdir -p ../pool-keys
cd ../pool-keys

# Link pool cold keys.
for p in $(seq 1 "$NB_POOL_NODES"); do
  i=$((NB_BFT_NODES+p))
  ln -sf "../pools/cold$p.skey" "node$i-cold.skey"
  ln -sf "../pools/cold$p.vkey" "node$i-cold.vkey"
done

cd ../utxo-keys

# Set up utxo-keys for pool use.
for p in $(seq 1 "$NB_POOL_NODES"); do
  i=$((NB_BFT_NODES+p))
  ln -sf "utxo1.skey" "utxo$i.skey"
  ln -sf "utxo1.vkey" "utxo$i.vkey"
done

# TODO fix script:
#../../scripts/renew-kes-keys.sh 0
