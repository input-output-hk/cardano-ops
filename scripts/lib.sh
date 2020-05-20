#!/usr/bin/env bash

fail() {
	echo -e "ERROR:  $1" >&2
	exit 1
}

failusage() {
        echo "USAGE:  $(basename "$0") $*" >&2
        exit 1
}

oprint() {
        echo "--( $*" >&2
}
export -f oprint
oprint_top() {
        ## This only prints if ran from the top-level shell process.
        if test -z "${lib_recursing}"; then oprint "$@"; fi
}
export -f oprint_top

vprint() {
        if test -n "${verbose}${debug}"; then echo "-- $*" >&2; fi
}
export -f vprint
vprint_top() {
        ## This only prints if either in debug mode,
        ## or ran from the top-level shell process.
        if test -z "${lib_recursing}" -o -n "${debug}"; then vprint "$@"; fi
}
export -f vprint_top

dprint() {
        if test -n "${debug}"; then echo "-- $*" >&2; fi
}
export -f dprint

fprint() {
        echo "-- FATAL:  $*" >&2
}
export -f fprint

jqtest() {
        jq --exit-status "$@" > /dev/null
}

## Reverse JQ -- essentially flips its two first args
rjq() {
        local f="$1"; q="$2"; shift 2
        jq "$q" "$f" "$@"
}

## Raw Reverse JQ -- as "rjq", but also --raw-output, for shell convenience.
rrjq() {
        local f="$1"; q="$2"; shift 2
        jq "$q" "$f" --raw-output "$@"
}

## Reverse JQ TEST -- as "rjq", but with --exit-status, for shell convenience.
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

        echo "${timestamp}.${commit}.${mnemonic}.${status}"
}
