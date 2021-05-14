#!/usr/bin/env bash

. $(dirname $0)/lib.sh

POOL_NODES=($POOL_NODES)

# Copy the scripts to the pool nodes
for f in ${POOL_NODES[@]}
do
    nixops scp $f examples/pivo-version-change/lib.sh /root/ --to
    nixops scp $f examples/pivo-version-change/run.sh /root/ --to
done

clear

# Register the stake pool.
#
# We need a registered stake pool so that we can delegate stake to it.
# Otherwise the stake keys do not count as active stake.
# Register the stake pools
echo
echo "Registering stake pools"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh register" &
done
wait
echo
echo "Stake pools registered"
echo

# Create one payment key and one stake key per-participant
echo
echo "Creating payment and staking keys"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh ckeys 10000" &
done
wait
echo
echo "Payment and staking keys created"
echo

# Transfer the funds the node controls to each of the keys created above
echo
echo "Transfering funds"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh tfunds" &
done
wait
echo
echo "Funds transfered"
echo

# Register a stake key for each of the spending keys created above.
echo
echo "Registering stake keys"
echo
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh regkey" &
done
wait
echo
echo "Stake keys registered"
echo

# Query the stake distribution snapshots
# > cardano-cli query ledger-state --testnet-magic 42 --pivo-era --pivo-mode | jq '.stateBefore.esSnapshots'

# Commit the SIP
echo
echo "Submitting an SIP commit using ${POOL_NODES[0]}"
echo
nixops ssh ${POOL_NODES[0]} "./run.sh scommit \"--voting-period-duration 9000\""

# Reveal the SIP
pretty_sleep 65 "Waiting for SIP submission to be stable"

echo
echo "Submitting an SIP revelation using ${POOL_NODES[0]}"
echo
nixops ssh ${POOL_NODES[0]} "./run.sh sreveal  \"--voting-period-duration 9000\""

# Vote on the SIP with all the stake keys created above
pretty_sleep 65 "Waiting for SIP revelation to be stable"

echo
echo "Voting on the SIP"
echo
echo "Voting process started on: $(mdate)" > voting-timing.log
for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./run.sh sip_skvote  \"--voting-period-duration 9000\"" &
done
# We wait till the end of the voting period
echo
echo "Start waiting on $(date)"
echo
pretty_sleep 1800 "Waiting till the voting period ends"
echo
echo "End waiting on $(date)"
echo
wait
echo "Voting process ended on: $(mdate)" >> voting-timing.log

pretty_sleep 30 "Waiting to query the ballots"
nixops ssh ${POOL_NODES[0]} "./run.sh qsipballot"

echo
echo "Done voting on the SIP"
echo
