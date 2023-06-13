#!/usr/bin/env bash

# A script to generate a topology reference file
# The output file will contain a map between $MACHINE-$NODE_INDEX and topology file for a given nixops cluster build realized path.
# Difference in topologies can then be quickly compared on a per machine basis across nixops builds with commands such as:
#
#   MACHINE=rel-a-1-0;
#   icdiff \
#     <(jq -S < $(grep "$MACHINE" oldtopo | awk '{print $2}')) \
#     <(jq -S < $(grep "$MACHINE" newtopo | awk '{print $2}'))

REL_NUM_INSTANCES="$1"
REALIZED_DIR="$2"
OUTFILE="$3"

if [ "$#" -ne 3 ]; then
  echo "Usage: gen-topo-map.sh <REL_NUM_INSTANCES> <REALIZED_DIR> <OUTFILE>"
  echo "Where:"
  echo "  <REL_NUM_INSTANCES> = The number of cardano-node instances running on each relay"
  echo "  <REALIZED_DIR>      = The nix-store realized output path which machine directories reside under"
  echo "  <OUTFILE>           = The output file to store topology paths found in the nixops realized directory"
  exit 0
fi

mapfile -t RELAYS < <(
  nix eval \
    --impure \
    --raw \
    --expr \
      'builtins.concatStringsSep "\n" (map (e: e.name) (import ./nix {}).globals.topology.relayNodes)' \
    2> /dev/null \
)

mapfile -t CORES < <(
  nix eval \
    --impure \
    --raw \
    --expr \
      'builtins.concatStringsSep "\n" (map (e: e.name) (import ./nix {}).globals.topology.coreNodes)' \
    2> /dev/null \
)

for i in "${RELAYS[@]}" "${CORES[@]}"; do
  if [[ "$i" =~ ^"rel" ]]; then
    for j in $(seq 0 "$((REL_NUM_INSTANCES - 1))"); do
    # shellcheck disable=SC2046
      echo -ne "$i-$j $( \
        grep ExecStart "$REALIZED_DIR/$i/etc/systemd/system/cardano-node-$j.service" \
          | cut -d = -f 2 \
          | cat $(cat -) \
          | grep topology \
          | tail -n 1 \
          | awk '{print $9}' \
        )\n" \
        >> "$OUTFILE"
    done
  else
    # shellcheck disable=SC2046
    echo -ne "$i-0 $( \
      grep ExecStart "$REALIZED_DIR/$i/etc/systemd/system/cardano-node.service" \
        | cut -d = -f 2 \
        | cat $(cat -) \
        | grep topology \
        | tail -n 1 \
        | awk '{print $9}' \
      )\n" \
      >> "$OUTFILE"
  fi
done
