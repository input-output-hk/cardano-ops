#!/usr/bin/env bash

set -euo pipefail

. lib.sh

CLI=cardano-cli

clear
tput sc

# Wait till we get a proposal in the state
pst="[]"
while [ "$pst" = "[]" ]; do
    pst=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq ".stateBefore.esLState.utxoState.ppups.ideationSt.proposalsState")
    tput rc
    clear
    echo "Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    $CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq ".stateBefore.esLState.utxoState.ppups.ideationSt"
    sleep 5
done

pst=""
while [ "$pst" != '"Approved"' ]; do
    pst=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.ideationSt.proposalsState[0][1].decisionInfo.decisionWas')
    tput rc
    clear
    echo "Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.ideationSt"
    sleep 5
done

pst="[]"
while [ "$pst" = '[]' ]; do
    pst=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.approvalSt.movedAway')
    tput rc
    clear
    echo "Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.approvalSt"
    sleep 5
done

ver=0
while [ $ver -ne 77 ]; do
    ver=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.activationSt.currentProtocol.implProtocolVersion')
    tput rc
    clear
    echo "Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.activationSt"
    sleep 5
done
