
#!/usr/bin/env bash

set -euo pipefail

USAGE="Usage: $0 TARGET_SIZE_GB node1 [node2 ... nodeN]"

if [ $# -lt 2 ]; then
	echo "$USAGE"
	exit 1
fi

TARGET_SIZE="$1"; shift

TARGET_NODES="";

while (( "$#" )); do
    TARGET_NODES="$TARGET_NODES $1"
    shift
done

cd "$(dirname "$0")/.."

DEPLOY_ID=$(nixops export -d $NIXOPS_DEPLOYMENT | jq -r 'keys | .[]')

for r in $TARGET_NODES; do
    REGION=$(nixops export | jq -r ".\"$DEPLOY_ID\".resources.\"$r\".\"ec2.region\"")
    VOL_ID=$(nixops export | jq -r ".\"$DEPLOY_ID\".resources.\"$r\".\"ec2.blockDeviceMapping\"" | jq -r '."/dev/xvda".volumeId')
    echo "resizing root volume for $r"

    aws --region $REGION ec2 modify-volume --size $TARGET_SIZE --volume-id $VOL_ID
 done

nixops ssh-for-each -p --include $TARGET_NODES -- 'nix-shell -p cloud-utils --run "growpart /dev/nvme0n1 1 && resize2fs /dev/disk/by-label/nixos"'
