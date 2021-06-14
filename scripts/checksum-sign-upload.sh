#!/usr/bin/env bash

set -euo pipefail

FILE=$1
BUCKET=$2
PREFIX=${3:-}
if [ $PREFIX = "" ]; then
  PATH_PREFIX=""
else
  PATH_PREFIX="/$PREFIX"
fi

if [[ $BUCKET == *"."* ]]; then
  HOST=$BUCKET
else
  HOST="$BUCKET.s3.amazonaws.com"
fi

sha256sum $FILE > "$FILE.sha256sum"
gpg --armor --detach-sign $FILE

for f in "$FILE.sha256sum" "$FILE.asc" "$FILE"; do
  echo "Uploading $f"

  aws s3api put-object \
    --bucket $BUCKET \
    --key $PREFIX/$(basename $f) \
    --body $f \
    --acl public-read
done

echo "Uploaded files:"
for f in "$FILE" "$FILE.sha256sum" "$FILE.asc"; do
  echo " * https://$HOST$PATH_PREFIX/$f"
done
