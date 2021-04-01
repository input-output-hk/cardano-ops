#!/usr/bin/env bash

# To keep things simple this script assumes it is run from a tmux session.

set -euo pipefail

nix-shell --run "./examples/pivo-version-change/redeploy.sh"

tmux split-window -d -t 0 -v
tmux split-window -d -t 0 -v
tmux select-layout even-horizontal

sleep 2

tmux send-keys -t 0 "rm keys -fr" Enter
tmux send-keys -t 0 "nix-shell --run \"./examples/pivo-version-change.sh\"" Enter
tmux send-keys -t 1 "nix-shell --run \"./examples/pivo-version-change/monitor-ustate.sh\"" Enter
tmux send-keys -t 2 "nix-shell --run \"./examples/pivo-version-change/tx-sub-loop.sh\"" Enter
