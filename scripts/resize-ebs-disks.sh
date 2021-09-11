
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

DEPLOY_JSON=$(nixops export -d $NIXOPS_DEPLOYMENT)
DEPLOY_ID=$(jq -r 'keys | .[]' <<< $DEPLOY_JSON)

for r in $TARGET_NODES; do
    AWS_PROFILE=$(jq -r ".\"$DEPLOY_ID\".resources.\"$r\".\"ec2.accessKeyId\"" <<< $DEPLOY_JSON)
    REGION=$(jq -r ".\"$DEPLOY_ID\".resources.\"$r\".\"ec2.region\"" <<< $DEPLOY_JSON)
    VOL_ID=$( (jq -r ".\"$DEPLOY_ID\".resources.\"$r\".\"ec2.blockDeviceMapping\"" | jq -r '."/dev/xvda".volumeId') <<< $DEPLOY_JSON)
    echo "resizing root volume for $r"
    export AWS_PROFILE
    aws --region $REGION ec2 modify-volume --size $TARGET_SIZE --volume-id $VOL_ID
 done

nixops ssh-for-each -p --include $TARGET_NODES -- 'nix-shell -p cloud-utils --run "growpart /dev/nvme0n1 1 && resize2fs /dev/disk/by-label/nixos"'
