#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1001
elapsedSeconds=$(( $(date +\%s) - $(date +\%s -d "$SYSTEM_START") ))
elapsedSecondsInEpoch=$(( elapsedSeconds % EPOCH_LENGTH ))
hoursSinceLastEpoch=$(( elapsedSecondsInEpoch / 3600 ))
echo $hoursSinceLastEpoch
