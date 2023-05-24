#!/usr/bin/env bash
#
# Create the genesis file for a libvirtd testnet, and the different keys that the nodes use.
# Keys and genesis files are placed in the `keys` directory by default.
# This script requires the following environment variables to be defined:
#
# - NB_BFT_NODES: number of BFT nodes
# - NB_POOL_NODES: number of staking pool nodes
# - K: the security parameter for the network
# - F: the active slot coefficient
# - MAX_SUPPLY: total lovelace supply
#
# These environment variables will obtain defaults upon entering a nix-shell,
# preferentially from the cluster's globals file, but otherwise using mainnet
# network parameters as a default fallback.
set -euo pipefail

# Leverage the cardano-world cluster spin up method and scripts to create a new world
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
WORLD="github:input-output-hk/cardano-world"
JOBS="$WORLD#$SYSTEM.automation.jobs"
COST_MODEL="$(nix eval --raw --impure --expr "(builtins.getFlake $WORLD).outPath")/docs/resources/cost-model-secp-preprod-mainnet.json"

PWD="$(pwd -P)"
PRJ_ROOT="$(git rev-parse --show-toplevel)"
[ "$PWD" != "$PRJ_ROOT" ] && { echo "This script must be run from the top level repo directory: $PRJ_ROOT"; exit 1; }
cd "$(dirname "$0")/.."

[ -z "${ENV_NAME:-}" ] && { ENV_NAME=$(nix eval --raw --impure --expr '(import ./nix {}).globals.environmentName') || ENV_NAME="localTest"; }
[ -z "${NB_BFT_NODES:-}" ] && { echo "Environment variable NB_BFT_NODES must be defined"; exit 1; }
[ -z "${NB_POOL_NODES:-}" ] && { echo "Environment variable NB_POOL_NODES must be defined"; exit 1; }
[ -z "${K:-}" ] && { echo "Environment variable K must be defined"; exit 1; }
[ -z "${F:-}" ] && { echo "Environment variable F must be defined"; exit 1; }
[ -z "${MAX_SUPPLY:-}" ] && { echo "Environment variable MAX_SUPPLY must be defined"; exit 1; }
[ -z "${SLOT_LENGTH:-}" ] && { echo "Environment variable SLOT_LENGTH (seconds) must be defined"; exit 1; }
[ -z "${NETWORK_MAGIC:-}" ] && { echo "Environment variable NETWORK_MAGIC must be defined"; exit 1; }

DELAY="${DELAY:-5}"
NUM_GENESIS_KEYS="${NB_POOL_NODES}"
GENESIS_DIR="$PRJ_ROOT/keys"
UTXO_KEYS="${UTXO_KEYS:-1}"
LOCAL_SOCKET="/tmp/node-$ENV_NAME.socket"
LOCAL_SSH_CONTROL="/tmp/node-$ENV_NAME"
REMOTE_SOCKET="/run/cardano-node/node.socket"
TIP_QUERY=("cardano-cli" "query" "tip" "--testnet-magic" "$NETWORK_MAGIC")
EPOCH_LENGTH_HOURS=$(bc <<< "scale=1; $K * 200 / 3600")
EPOCH_LENGTH_DAYS=$(bc <<< "scale=1; $K * 200 / 86400")
export CARDANO_NODE_SOCKET_PATH="$LOCAL_SOCKET"

# Functions Start ------------------------------------------


WAIT_FOR_EPOCH() {
  EPOCH="$1"

  echo "Waiting for epoch $EPOCH or greater..."
  while true; do
    if "${TIP_QUERY[@]}" | jq -e ".epoch >= $EPOCH" &> /dev/null; then
      break
    else
      echo "Waiting for epoch $EPOCH+, $("${TIP_QUERY[@]}" | jq -e '.slotsToEpochEnd') slots remain..."
      sleep 20
    fi
  done

  sleep 120
}

PROMPT_CHECK() {
  MSG="$1"
  if [ "$USE_EXISTING" = "TRUE" ]; then
    echo
    read -p "$MSG" -n 1 -r
    echo
  fi

  if [ "$USE_EXISTING" = "FALSE" ] || [[ "${REPLY:-n}" =~ ^[Yy]$ ]]; then
    return 0
  fi

  return 1
}


# Functions End --------------------------------------------


# Most of these vars are tied to cardano-ops globals declarations
echo "About to generate a new cardano cluster genesis and keys using following environment variables:

  ENV_NAME=$ENV_NAME (environment name, typically declared in globals.environmentName)
  NB_BFT_NODES=$NB_BFT_NODES (number of bft core nodes)
  NB_POOL_NODES=$NB_POOL_NODES (number of staking pool nodes)
  K=$K (Security parameter)
  F=$F (Active slots coefficient)
  MAX_SUPPLY=$MAX_SUPPLY (Max Lovelace supply)
  SLOT_LENGTH=$SLOT_LENGTH
  NETWORK_MAGIC=$NETWORK_MAGIC
  DELAY=$DELAY (delay in minutes before genesis systemStart)
  DOMAIN=$DOMAIN
  RELAYS=$RELAYS
  NUM_GENESIS_KEYS=$NUM_GENESIS_KEYS
  GENESIS_DIR=$GENESIS_DIR
  UTXO_KEYS=$UTXO_KEYS
  DEBUG=${DEBUG:-Disabled}


INFO: Current K parameter will yield epoch length of $EPOCH_LENGTH_HOURS hours or $EPOCH_LENGTH_DAYS days (rounded)
      Useful values of K for epoch length selection are:
      K = 2160, epoch length is 5 days
      K = 432,  epoch length is 1 day
      K = 36,   epoch length is 2 hours

"

# Ensure that at least one stake pool is present to start with BFT creds and convert to pool creds
[ "$NB_POOL_NODES" -lt 1 ] && { echo "Environment variable NB_POOL_NODES must be at least 1"; exit 1; }


[ "$NB_BFT_NODES" -ne 0 ] && {
  echo "WARNING: This script is not intended to handle BFT nodes."
  echo "         Unless you know what you are doing, only stakepools should be declared in the topology."
  echo
}

if [ -d "$GENESIS_DIR" ]; then
  read -p "Genesis directory already exists at $GENESIS_DIR."$'\nDo you wish to proceed using the existing genesis and keys? ' -n 1 -r
  [[ $REPLY =~ ^[Yy]$ ]] || { echo; echo "Please delete the $GENESIS_DIR and re-run this script to generate new genesis and keys. Exiting."; exit 0; }
  USE_EXISTING="TRUE"
else
  USE_EXISTING="FALSE"
  read -p "Do you wish to proceed? " -n 1 -r
  [[ $REPLY =~ ^[Yy]$ ]] || { echo; echo "Please adjust parameters and retry. Exiting."; exit 0; }
  echo
  echo

  # The cardano-ops declared globals vars are shimmed to cardano-world job vars when needed
  echo "Generating custom node config genesis and keys..."
  [ -n "${DEBUG:-}" ] && export DEBUG
  export PRJ_ROOT
  export NUM_GENESIS_KEYS
  export GENESIS_DIR
  START_TIME=$(date -u -d "today + $DELAY minutes" +'%Y-%m-%dT%H:%M:%SZ') \
  SLOT_LENGTH=$((SLOT_LENGTH * 1000)) \
  SECURITY_PARAM="$K" \
  TESTNET_MAGIC="$NETWORK_MAGIC" \
  nix run "$JOBS.gen-custom-node-config" --refresh

  # Post process for params which are not parameterized in cardano-world job automation
  # The epoch length must satisfy: 10 * securityParam / activeSlotsCoeff <= epochLength
  # So we set the epoch length to exactly the value of the left hand side of the inequality.
  EPOCH_LENGTH=$(perl -E "say ((10 * $K) / $F)")
  sed -Ei "s/^([[:blank:]]*\"activeSlotsCoeff\":)([[:blank:]]*[^,]*,)$/\1 $F,/" "$GENESIS_DIR/shelley-genesis.json"
  sed -Ei "s/^([[:blank:]]*\"epochLength\":)([[:blank:]]*[^,]*,)$/\1 $EPOCH_LENGTH,/" "$GENESIS_DIR/shelley-genesis.json"
  sed -Ei "s/^([[:blank:]]*\"maxLovelaceSupply\":)([[:blank:]]*[^,]*,)$/\1 $MAX_SUPPLY,/" "$GENESIS_DIR/shelley-genesis.json"

  # Set the byron nonAvvmBalance to match max supply also set in shelley genesis
  NON_AVVM_KEY=$(jq -r '.nonAvvmBalances | to_entries | map(select(.value != "0"))[].key' < "$GENESIS_DIR/byron-genesis.json")
  jq \
    --sort-keys \
    --arg MAX_SUPPLY "$MAX_SUPPLY" \
    --arg NON_AVVM_KEY "$NON_AVVM_KEY" \
    '.nonAvvmBalances."\($NON_AVVM_KEY)" = "\($MAX_SUPPLY)"' \
    < "$GENESIS_DIR/byron-genesis.json" \
    > "$GENESIS_DIR/byron-genesis.json.tmp"
  mv "$GENESIS_DIR/byron-genesis.json.tmp" "$GENESIS_DIR/byron-genesis.json"

  # Shim the cardano-world outputs to cardano-ops expectations
  BYRON_HASH=$(cardano-cli byron genesis print-genesis-hash --genesis-json "$GENESIS_DIR/byron-genesis.json" | tee "$GENESIS_DIR/byron-genesis.hash")
  SHELLEY_HASH=$(cardano-cli genesis hash --genesis "$GENESIS_DIR/shelley-genesis.json" | tee "$GENESIS_DIR/shelley-genesis.hash")
  cardano-cli genesis hash --genesis "$GENESIS_DIR/alonzo-genesis.json" > "$GENESIS_DIR/alonzo-genesis.hash"
  cardano-cli genesis hash --genesis "$GENESIS_DIR/conway-genesis.json" > "$GENESIS_DIR/conway-genesis.hash"

  # Update to the correct genesis hashes in the node config
  jq \
    --sort-keys \
    --arg BYRON_HASH "$BYRON_HASH" \
    --arg SHELLEY_HASH "$SHELLEY_HASH" \
    '. |= . + {"ByronGenesisHash": "\($BYRON_HASH)", "ShelleyGenesisHash": "\($SHELLEY_HASH)"}' \
    < "$GENESIS_DIR/node-config.json" \
    > "$GENESIS_DIR/node-config.json.tmp"
  mv "$GENESIS_DIR/node-config.json.tmp" "$GENESIS_DIR/node-config.json"

  # Generate a rich key for the cluster
  cardano-cli address key-gen \
    --signing-key-file "$GENESIS_DIR/utxo-keys/rich-utxo.skey" \
    --verification-key-file "$GENESIS_DIR/utxo-keys/rich-utxo.vkey"

  # Build an address for the new rich key
  cardano-cli address build \
    --payment-verification-key-file "$GENESIS_DIR/utxo-keys/rich-utxo.vkey" \
    --testnet-magic "$NETWORK_MAGIC" \
    > "$GENESIS_DIR/utxo-keys/rich-utxo.addr"

  mkdir -p "$GENESIS_DIR/node-keys"
  cd "$GENESIS_DIR/node-keys"

  # Create required Cardano TPraos symlinks for nixops key deployment
  for i in $(seq 0 $((NB_POOL_NODES - 1))); do
    ln -sf "../delegate-keys/shelley.00$i.vrf.skey" "node-vrf$((i + 1)).skey"
    ln -sf "../delegate-keys/shelley.00$i.kes.skey" "node-kes$((i + 1)).skey"
    ln -sf "../delegate-keys/shelley.00$i.opcert.json" "node$((i + 1)).opcert"
  done
fi

# A pre-existing cluster can be cleared before running this script for a fresh start with:
# nixops ssh-for-each -- 'systemctl stop cardano-node || true; rm -rf /var/lib/cardano-node || true'
echo
echo
if [ "$USE_EXISTING" = "TRUE" ]; then
  read -p "Do you wish to nixops [re-]deploy using existing genesis and BFT keys? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    echo "Deploying the cluster with pre-existing genesis and BFT keys from $GENESIS_DIR..."
    nixops deploy
  fi
else
  echo "Deploying the cluster with genesis and BFT keys from $GENESIS_DIR..."
  nixops deploy
fi

# Cardano-address required by some cardano-world job automation.
# It isn't needed anywhere else in the repo, so rather than add
# an extra potentially long load time binary into the nix-shell
# for everyone, just bring it into scope only for this script.
echo
echo
echo "Bringing cardano-address into sub-shell scope."
# shellcheck disable=SC2139
CARDANO_ADDRESS="$(
  nix build \
  "github:input-output-hk/cardano-world#$SYSTEM.cardano.packages.cardano-address" \
  --no-link \
  --print-out-paths \
  2> /dev/null
)/bin/cardano-address"

cardano-address() {
  "$CARDANO_ADDRESS" "$@"
}
export CARDANO_ADDRESS
export -f cardano-address

# The initial pool used for obtaining a live node socket.
# This requires a libvirtd cluster using the default virbr0 bridge to work.
echo
echo
cd "$PRJ_ROOT"
LIBVIRT_DNS=$(ip -4 -j a show dev virbr0 | jq -r '.[].addr_info[].local')
BOOTSTRAP_POOL=$(nix eval --impure --raw --expr 'builtins.elemAt (map (r: r.name) (import ./nix {}).globals.topology.coreNodes) 0')
BOOTSTRAP_IP=$(dig +short "@$LIBVIRT_DNS" "$BOOTSTRAP_POOL")
echo "Bootstrap pool is $BOOTSTRAP_POOL at ipv4 $BOOTSTRAP_IP"

# Close persistent conns on exit.
# If needed, the manual equivalent is typically:
#   ssh -S "/tmp/node-$ENV_NAME" -O exit root@$(dig +short @192.168.122.1 stk-a-1-IOHK1)
CLEANUP() {
  ssh -S "$LOCAL_SSH_CONTROL" -O exit "root@$BOOTSTRAP_IP" &> /dev/null || true
}
trap CLEANUP EXIT

# Obtain a remote cardano-node socket locally and persist it until the script exits.
while true; do
  if nixops ssh "$BOOTSTRAP_POOL" -- '[ -S /run/cardano-node/node.socket ]' &> /dev/null; then
    ssh \
      -o ControlPath="$LOCAL_SSH_CONTROL" \
      -o ControlMaster=auto \
      -o ControlPersist=yes \
      -o StreamLocalBindUnlink=yes \
      -L "$LOCAL_SOCKET:$REMOTE_SOCKET" \
      -N \
      -f \
      "root@$BOOTSTRAP_IP"
    echo "Socket connection to $BOOTSTRAP_POOL at ssh control $LOCAL_SSH_CONTROL and local socket file $LOCAL_SOCKET established."
    break
  else
    echo "Waiting 10 seconds for /run/cardano-node/node.socket on $BOOTSTRAP_POOL"
    sleep 10
  fi
done

# Ensure we can connect to the chain.
while true; do
  if timeout 10 "${TIP_QUERY[@]}" 2> /dev/null; then
    break
  else
    echo "Waiting for a successful chain tip query..."
  fi
done

# Ensure blocks are being forged.
while true; do
  if "${TIP_QUERY[@]}" | jq -e '.block >= 3' &> /dev/null; then
    break
  else
    echo "Waiting for at least 3 BFT blocks to be forged..."
    sleep 20
  fi
done

if PROMPT_CHECK "Do you wish to [re-]issue the transaction to move genesis utxo to a shelley rich key? "; then
  echo
  echo "Moving genesis funds to a shelley rich key."
  PAYMENT_ADDRESS=$(cat "$GENESIS_DIR/utxo-keys/rich-utxo.addr") \
  BYRON_SIGNING_KEY="$GENESIS_DIR/utxo-keys/shelley.000.skey" \
  TESTNET_MAGIC="$NETWORK_MAGIC" \
  SUBMIT_TX="TRUE" \
  ERA="--alonzo-era" \
  nix run "$JOBS.move-genesis-utxo" --refresh
  echo "Waiting 1 minute for transaction UTxO to settle..."
  sleep 60
fi

if PROMPT_CHECK "Do you wish to [re-]issue the transaction to create stake pools? "; then
  echo
  echo "Creating stake-pools."
  PAYMENT_KEY="$GENESIS_DIR/utxo-keys/rich-utxo" \
  NUM_POOLS="$NB_POOL_NODES" \
  START_INDEX=1 \
  STAKE_POOL_OUTPUT_DIR="$GENESIS_DIR/stake-pools" \
  POOL_RELAY="relay.$RELAYS" \
  POOL_RELAY_PORT=3001 \
  TESTNET_MAGIC="$NETWORK_MAGIC" \
  SUBMIT_TX="TRUE" \
  ERA="--alonzo-era" \
  nix run "$JOBS.create-stake-pools" --refresh
  echo "Waiting 1 minute for transaction UTxO to settle..."
  sleep 60
fi

WAIT_FOR_EPOCH "1"

if PROMPT_CHECK "Do you wish to [re-]issue the proposal update including d=0, hardfork to babbage, cost model and mainnet parameter matching? "; then
  echo
  echo "Updating proposal for d=0, hardfork to babbage, cost model and mainnet parameter matching."
  COST_MODEL_LIST="cost-model-secp-preprod-mainnet-list.json"

  # Node >= 8.0.0 doesn't like the hash map plutus cost model format and requires the list format.
  # Use jq to transform as needed.
  jq \
    --sort-keys \
    '.PlutusV1 = (.PlutusV1 | to_entries | map(.value)) | .PlutusV2 = (.PlutusV2 | to_entries | map(.value))' \
  < "$COST_MODEL" \
  > "$COST_MODEL_LIST"

  # Bundle the decentralization, hard-fork, cost model and mainnet matching params into one proposal update.
  PROPOSAL_ARGS=(
    "--decentralization-parameter" "0"
    "--protocol-major-version" "7"
    "--protocol-minor-version" "0"
    "--cost-model-file" "$COST_MODEL_LIST"
    "--max-block-body-size" "90112"
    "--number-of-pools" "500"
    "--max-block-execution-units" '(20000000000,62000000)'
    "--max-tx-execution-units" '(10000000000,14000000)'
  )
  PAYMENT_KEY="$GENESIS_DIR/utxo-keys/rich-utxo" \
  NUM_GENESIS_KEYS="$NB_POOL_NODES" \
  KEY_DIR="$GENESIS_DIR" \
  TESTNET_MAGIC="$NETWORK_MAGIC" \
  SUBMIT_TX="TRUE" \
  ERA="--alonzo-era" \
  nix run "$JOBS.update-proposal-generic" --refresh -- "${PROPOSAL_ARGS[@]}"
  echo "Waiting 1 minute for transaction UTxO to settle..."
  sleep 60
fi

if PROMPT_CHECK "Do you wish to [re-]execute the BFT credential to pool credential switch and re-deploy? "; then
  echo
  echo "Transitioning from BFT to pool credentials."
  while true; do
    if "${TIP_QUERY[@]}" | jq -e '.slotsToEpochEnd <= 60' &> /dev/null; then
      break
    else
      echo "Waiting for the end of epoch, $("${TIP_QUERY[@]}" | jq -e '.slotsToEpochEnd') slots remain..."
      sleep 20
    fi
  done

  echo "Confirming end of epoch..."
  sleep 120
  while true; do
    if "${TIP_QUERY[@]}" | jq -e '.slotsToEpochEnd <= 60' &> /dev/null; then
      echo "Confirmed end of epoch."
      break
    else
      echo "Waiting for the end of epoch, $("${TIP_QUERY[@]}" | jq -e '.slotsToEpochEnd') slots remain..."
      sleep 20
    fi
  done

  echo
  echo "Linking pool secrets..."

  # Create required Cardano TPraos symlinks for nixops key deployment
  cd "$GENESIS_DIR/node-keys"
  for i in $(seq 1 "$NB_POOL_NODES"); do
    ln -sf "../stake-pools/sp-$i-vrf.skey" "node-vrf$i.skey"
    ln -sf "../stake-pools/sp-$i-kes.skey" "node-kes$i.skey"
    ln -sf "../stake-pools/sp-$i.opcert" "node$i.opcert"
  done

  cd "$PRJ_ROOT"
  echo "Deploying pool secrets..."
  nixops deploy
fi

echo
echo "Create genesis and keys for libvirtd shelley+ cluster completed."
