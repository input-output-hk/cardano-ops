#!/usr/bin/env bash

set -euo pipefail

USAGE="Usage: $0 TARGET_SIZE_GB node1 [node2 ... nodeN]"

if [ $# -lt 2 ]; then
  echo "$USAGE"
  exit 1
fi

TARGET_SIZE="$1"; shift
TARGET_NODES=("$@")

cd "$(dirname "$0")/.."

DEPLOY_JSON=$(nixops export -d "$NIXOPS_DEPLOYMENT")

for r in "${TARGET_NODES[@]}"; do
    AWS_PROFILE=$(jq -r ".[].resources.\"$r\".\"ec2.accessKeyId\"" <<< "$DEPLOY_JSON")
    REGION=$(jq -r ".[].resources.\"$r\".\"ec2.region\"" <<< "$DEPLOY_JSON")
    VOL_ID=$( (jq -r ".[].resources.\"$r\".\"ec2.blockDeviceMapping\"" | jq -r ".\"/dev/xvda\".volumeId") <<< "$DEPLOY_JSON")
    echo "resizing root volume for $r (profile: $AWS_PROFILE region: $REGION volume: $VOL_ID)"
    export AWS_PROFILE
    aws --region "$REGION" ec2 modify-volume --size "$TARGET_SIZE" --volume-id "$VOL_ID"
 done

nixops ssh-for-each -p --include "${TARGET_NODES[@]}" -- '
  nix-shell -p cloud-utils --run "
    (growpart /dev/xvda 1 || growpart /dev/nvme0n1 2) && resize2fs /dev/disk/by-label/nixos"
'
