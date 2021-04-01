#!/usr/bin/env bash

# To keep things simple this script assumes it is run from a tmux session.

nix-shell

nixops destroy --confirm
./scripts/create-shelley-genesis-and-keys.sh
nixops deploy -k

tmux split-window -d -t 0 -v
tmux split-window -d -t 0 -v
tmux select-layout even-horizontal

sleep 2

tmux send-keys -t 0 "rm keys -fr && nix-shell" Enter
tmux send-keys -t 0 "./examples/pivo-version-change.sh" Enter
tmux send-keys -t 1 "./examples/pivo-version-change/monitor-ustate.sh" Enter
tmux send-keys -t 2 "./examples/pivo-version-change/tx-sub-loop.sh" Enter
