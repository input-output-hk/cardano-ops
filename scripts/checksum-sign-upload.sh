#!/usr/bin/env bash

set -euo pipefail

FILE=$1
BUCKET=$2
PREFIX=${3:-}
if [ $PREFIX = "" ]; then
  PATH_PREFIX=""
else
  PATH_PREFIX="$PREFIX/"
fi

if [[ $BUCKET == *"."* ]]; then
  HOST=$BUCKET
else
  HOST="$BUCKET.s3.amazonaws.com"
fi

sha256sum $FILE > "$FILE.sha256sum"
gpg --armor --detach-sign $FILE

export PYTHONPATH=
for f in "$FILE.sha256sum" "$FILE.asc" "$FILE"; do
  echo "Uploading $f"

  s3cmd put --acl-public --multipart-chunk-size-mb=512 $f s3://$BUCKET/$PREFIX
done

echo "Uploaded files:"
for f in "$FILE" "$FILE.sha256sum" "$FILE.asc"; do
  echo " * https://$HOST$PATH_PREFIX/$f"
done
