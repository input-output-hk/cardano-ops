#!/usr/bin/env bash
# shellcheck disable=1091,2016

sheet_list=()

sheet_list+=(sheet_message_types_summary)
sheet_message_types_summary() {
        local dir=${1:-.} name
        name=$(echo ${FUNCNAME[0]} | cut -d_ -f2-)

        mkdir -p "$dir"/report

jq ' .message_types
   | to_entries
   | map ( .key as $mach
         | .value
         | to_entries
         | map([ $mach, .key, .value | tostring]))
   | add
   | .[]
   | join(",")' < "$dir"/analysis.json --raw-output \
                > "$dir"/report/"$name".csv

sed -i '1inode, message, occurences' "$dir"/report/"$name".csv
}
