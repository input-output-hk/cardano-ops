#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1001
elapsedSeconds=$(( $(date +\%s) - $(date +\%s -d "$SYSTEM_START") ))
elapsedSecondsInEpoch=$(( elapsedSeconds % EPOCH_LENGTH ))
secondsUntilNextEpoch=$(( EPOCH_LENGTH - elapsedSecondsInEpoch ))
hoursUntilNextEpoch=$(( secondsUntilNextEpoch / 3600 ))
echo $hoursUntilNextEpoch
