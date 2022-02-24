
#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

RELAYS=$(nix eval --impure --raw --expr '(toString (map (r: r.name) (import ./nix {}).globals.topology.relayNodes))')

TARGET_SIZE=$(nix eval --impure --expr '(with (import ./nix {}).globals; systemDiskAllocationSize + nodeDbDiskAllocationSize * nbInstancesPerRelay)')

./scripts/resize-ebs-disks.sh $TARGET_SIZE $RELAYS
