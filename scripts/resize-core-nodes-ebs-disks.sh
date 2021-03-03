
#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

CORE_NODES=$(nix eval --raw '(toString (map (r: r.name) (import ./nix {}).globals.topology.coreNodes))')

TARGET_SIZE=$(nix eval '(with (import ./nix {}).globals; systemDiskAllocationSize + nodeDbDiskAllocationSize)')

./scripts/resize-ebs-disks.sh $TARGET_SIZE $CORE_NODES
