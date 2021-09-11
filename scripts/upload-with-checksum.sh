#!/usr/bin/env bash

set -euo pipefail

cd $(dirname "$1")
FILE="$(basename "$1")"
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

sha256sum "$FILE" > "$FILE.sha256sum"

export PYTHONPATH=
for f in "$FILE.sha256sum" "$FILE"; do
  >&2 echo "Uploading $f"

  >&2 s3cmd put --acl-public --multipart-chunk-size-mb=512 $f s3://$BUCKET/$PATH_PREFIX
done

echo "Uploaded files:"
for f in "$FILE.sha256sum" "$FILE"; do
  echo " - https://$HOST/$PATH_PREFIX$f"
done
