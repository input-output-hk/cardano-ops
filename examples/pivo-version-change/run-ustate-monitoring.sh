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
    echo "🕐 Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    echo
    echo "💡 Ideation state:"
    echo
    echo "Waiting on a proposal ..."
    sleep 5
done

pst=""
while [ "$pst" != '"Approved"' ]; do
    pst=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.ideationSt.proposalsState[0][1].decisionInfo.decisionWas')
    tput rc
    clear
    echo "🕐 Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    echo
    echo "💡 Ideation state:"
    echo
    echo "Ballot: "
    ($CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.ideationSt.proposalsState[0][1].ballot | .[][0][]" 2> /dev/null ) || true
    echo
    echo "Decision: $pst"
    sleep 5
done

pst="[]"
while [ "$pst" = '[]' ]; do
    pst=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.approvalSt.movedAway')
    tput rc
    clear
    echo "🕐 Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    echo
    echo "🤝 Approval state"
    echo
    echo "Ballot: "
    ($CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.approvalSt.proposalsState | .[] | .ballot | .[][0][]" 2> /dev/null) || true
    echo
    echo -ne "Decision: "
    ($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
        | jq '.stateBefore.esLState.utxoState.ppups.approvalSt.proposalsState | .[] | .decisionInfo.decisionWas' 2> /dev/null) || echo -ne "N/A"
    sleep 5
done

ver=0
while [ $ver -ne 77 ]; do
    ver=$($CLI query ledger-state --testnet-magic 42 \
               --pivo-era --pivo-mode \
              | jq '.stateBefore.esLState.utxoState.ppups.activationSt.currentProtocol.implProtocolVersion')
    tput rc
    clear
    echo "🕐 Slot: $($CLI query tip --testnet-magic 42 | jq .slot)"
    echo
    echo "🗲 Activation state"
    echo
    echo -ne "Current version: "
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.activationSt.currentProtocol.implProtocolVersion"
    echo
    echo -ne "Endorsed proposal: "
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.activationSt.endorsedProposal.tag"
    echo
    echo -ne "Endorsed proposal version: "
    ($CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.activationSt.endorsedProposal.cProtocol.implProtocolVersion" 2> /dev/null) || echo -ne "No candidate"
    echo
    echo -ne "Endorsements: "
    $CLI query ledger-state --testnet-magic 42 \
         --pivo-era --pivo-mode \
        | jq ".stateBefore.esLState.utxoState.ppups.activationSt.endorsedProposal.cEndorsements.thisEpochEndorsements | .[][]"
    echo
    echo -ne "Maximum block body size: "
    $CLI query protocol-parameters --testnet-magic 42 \
         --shelley-era --shelley-mode | jq .maxBlockBodySize
    echo
    sleep 5
done
