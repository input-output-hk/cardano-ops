#!/usr/bin/env bash

msg() {
        echo "$*" >&2
}

msg_ne() {
        echo -ne "$*" >&2
}

fail() {
	msg "$*"
	exit 1
}

failusage() {
        msg "USAGE:  $(basename "$0") $*"
        exit 1
}

oprint() {
        msg "--( $*"
}
export -f oprint
oprint_ne() {
        msg_ne "--( $*"
}

oprint_top() {
        ## This only prints if ran from the top-level shell process.
        if test -z "${lib_recursing}"; then oprint "$@"; fi
}
export -f oprint_top

vprint() {
        if test -n "${verbose}${debug}"; then msg "-- $*"; fi
}
export -f vprint
vprint_top() {
        ## This only prints if either in debug mode,
        ## or ran from the top-level shell process.
        if test -z "${lib_recursing}" -o -n "${debug}"; then vprint "$@"; fi
}
export -f vprint_top

dprint() {
        if test -n "${debug}"; then msg "-- $*"; fi
}
export -f dprint

errprint() {
        msg_ne "***\n*** ERROR:  $*\n***\n"
}

fprint() {
        msg "-- FATAL:  $*"
}
export -f fprint

jqtest() {
        jq --exit-status "$@" > /dev/null
}

## Null input jq test
njqtest() {
        jqtest --null-input "$@"
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

timestamp() {
        date +'%Y''%m''%d''%H''%M'
}

words_to_lines() {
        sed 's_ _\n_g'
}

json_file_append() {
        local f=$1 extra=$2 tmp; shift 2
        tmp=$(mktemp --tmpdir)

        test -f "$f" || echo "{}" > "$f"
        jq ' $origf[0] as $orig
           | $orig * ('"$extra"')
           ' --slurpfile origf "$f" "$@" > "$tmp"
        mv "$tmp"  "$f"
}

json_file_prepend() {
        local f=$1 extra=$2 tmp; shift 2
        tmp=$(mktemp --tmpdir)

        test -f "$f" || echo "{}" > "$f"
        jq ' $origf[0] as $orig
           | ('"$extra"') * $orig
           ' --slurpfile origf "$f" "$@" > "$tmp"
        mv "$tmp"  "$f"
}

shell_list_to_json() {
        words_to_lines | jq --raw-input | jq --slurp --compact-output
}

generate_mnemonic()
{
        local mnemonic timestamp commit status
        mnemonic=$(nix-shell -p diceware --run 'diceware --no-caps --num 2 --wordlist en_eff -d-')
        # local timestamp=$(date +%s)
        timestamp=$(timestamp)
        commit=$(git rev-parse HEAD | cut -c-8)
        status=''

        if git diff --quiet --exit-code
        then status=
        else status=+
        fi

        echo "${timestamp}.${commit}${status}.${mnemonic}"
}

maybe_local_repo_branch() {
        local local_repo_path=$1 rev=$2
        git -C "$local_repo_path" describe --all "$rev" |
                sed 's_^\(.*/\|\)\([^/]*\)$_\2_'
        ## This needs a shallow clone to be practical.
}

min() {
        if test "$1" -gt "$2"; then echo -n "$2"; else echo -n "$1"; fi
}

max() {
        if test "$1" -lt "$2"; then echo -n "$2"; else echo -n "$1"; fi
}
