#!/usr/bin/env bash

set -euo pipefail


FEE="${FEE:-250000}"
PAYMENT_KEY_PREFIX="${PAYMENT_KEY_PREFIX:-keys/utxo-keys/utxo1}"
CARDANO_NODE_SOCKET_PATH="${CARDANO_NODE_SOCKET_PATH:-$PWD/node.socket}"
export CARDANO_NODE_SOCKET_PATH

USAGE="Usage: $0 versionMajor versionMinor [targetEpoch] \n
$0 path/to/update.proposal \n
(use current epoch if not provided) \n
\n
Environnement variables: \n
\n
 - FEE ($FEE)\n
 - PAYMENT_KEY_PREFIX ($PAYMENT_KEY_PREFIX)\n
 - CARDANO_NODE_SOCKET_PATH ($CARDANO_NODE_SOCKET_PATH)
"

if [ $# -eq 1 ]; then
  UPDATE_PROPOSAL=$1
else
  if [ $# -lt 2 ]; then
    echo -e "$USAGE"
    exit 1
  else
    MAJOR=$1
    MINOR=$2
    EPOCH=${3:-$(cardano-cli query tip --testnet-magic "$NETWORK_MAGIC" | jq .epoch)}
    UPDATE_PROPOSAL=""
  fi
fi

set -x

ADDR=$(cat "$PAYMENT_KEY_PREFIX.addr")
ADDR_AMOUNT=$(cardano-cli query utxo --address "$ADDR" --testnet-magic "$NETWORK_MAGIC" | awk '{if(NR==3) print $3}')
UTXO=$(cardano-cli query utxo --address "$ADDR" --testnet-magic "$NETWORK_MAGIC" | awk '{if(NR==3) print $1 "#" $2}')

if [ -z "$UPDATE_PROPOSAL" ]; then
  UPDATE_PROPOSAL="keys/update-to-protocol-v$MAJOR.$MINOR.proposal"
  # shellcheck disable=SC2046
  cardano-cli governance create-update-proposal \
    --epoch "$EPOCH" \
    --protocol-major-version "$MAJOR" \
    --protocol-minor-version "$MINOR" \
    $(for g in keys/genesis-keys/genesis?.vkey; do echo " --genesis-verification-key-file $g"; done) \
    --out-file "$UPDATE_PROPOSAL"
fi

ERA=$(cardano-cli query tip --testnet-magic "$NETWORK_MAGIC" | jq -r '.era | ascii_downcase')

cardano-cli transaction build-raw \
  "--$ERA-era" \
  --ttl 100000000 \
  --tx-in "$UTXO" \
  --tx-out "$ADDR+$((ADDR_AMOUNT - FEE))" \
  --update-proposal-file "$UPDATE_PROPOSAL" \
  --out-file "$UPDATE_PROPOSAL.txbody" \
  --fee "$FEE"

# shellcheck disable=SC2046
cardano-cli transaction sign \
  --tx-body-file "$UPDATE_PROPOSAL.txbody" \
  --out-file "$UPDATE_PROPOSAL.tx" \
  --signing-key-file "$PAYMENT_KEY_PREFIX.skey" \
  $(for d in keys/delegate-keys/delegate?.skey; do echo " --signing-key-file $d"; done)

echo "Press enter to submit update proposal"
read -r -n 1

cardano-cli transaction submit \
  --tx-file "$UPDATE_PROPOSAL.tx" \
  --testnet-magic "$NETWORK_MAGIC"
