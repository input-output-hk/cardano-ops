#!/usr/bin/env bash

set -euo pipefail

elapsedSeconds=$(( $(date +\%s) - $(date +\%s -d "$SYSTEM_START") ))
elapsedSecondsInEpoch=$(( $elapsedSeconds % $EPOCH_LENGTH ))
hoursSinceLastEpoch=$(( $elapsedSecondsInEpoch / 3600 ))
echo $hoursSinceLastEpoch
