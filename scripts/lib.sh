#!/usr/bin/env bash

fail() {
	echo -e "ERROR:  $1" >&2
	exit 1
}

failusage() {
        echo "USAGE:  $(basename "$0") $*" >&2
        exit 1
}

jqtest() {
        jq --exit-status "$@" > /dev/null
}

## AKA "reverse jq", -- essentially flips its two first args
rjq() {
        local f="$1"; q="$2"; shift 2
        jq "$q" "$f" "$@"
}

## AKA "raw reverse jq", as "rjq", but also --raw-output, for shell.
rrjq() {
        local f="$1"; q="$2"; shift 2
        jq "$q" "$f" --raw-output "$@"
}

## AKA "reverse jq test", as "rjq", but with --exit-status, for shell
rjqtest() {
        local f="$1"; q="$2"; shift 2
        jq --exit-status "$q" "$f" "$@" >/dev/null
}

generate_mnemonic()
{
        local mnemonic=$(nix-shell -p diceware --run 'diceware --no-caps --num 2 --wordlist en_eff -d-')
        local timestamp=$(date +%s)
        local commit=$(git rev-parse HEAD | cut -c-8)
        local status=''

        if git diff --quiet --exit-code
        then status=pristine
        else status=modified
        fi

        echo "${timestamp}.${commit}.${status}.${mnemonic}"
}
