#!/usr/bin/env bash

set -eo pipefail

this_repo=$(git rev-parse --show-toplevel)

stage_changes=

while test -n "$1"
do case "$1" in
           --stage | --stage-changes )
                                  stage_changes=t;;
           --help )               usage; exit 1;;
           * ) break;; esac; shift; done
set -u

other_repo=${1:-$(realpath "$this_repo"/../cardano-benchmarking)}
other_project=$other_repo/cabal.project
other_name=$(basename "$other_repo")

repos=(
        "$other_name"
        cardano-node
)

repo_path() {
        echo -n "../$1"
}

repo_project() {
        echo -n "../$1/cabal.project"
}

dir_nix_hash() {
        local dir=$1
        local commit=$2
        pushd "${dir}" >/dev/null || return
        nix-prefetch-git "file://$(realpath "${dir}")" "${commit}" 2>/dev/null \
                | jq '.sha256' | xargs echo
        popd >/dev/null || return
}

cabal_project_current_commit() {
        local project_file=$1
        local repo_name=$2
        grep "^[ ]*location: .*/${repo_name}\$" "${project_file}" -A1 \
                | tail -n-1 | sed 's/^.* tag: //'
}

cabal_project_current_hash() {
        local project_file=$1
        local repo_name=$2
        grep "^[ ]*location: .*/${repo_name}\$" "${project_file}" -A2 \
                | tail -n-1 | sed 's/^.* --sha256: //'
}

fail() {
    echo "$*" >&2
    exit 1
}

test -r "$other_project" ||
        fail "Usage:  $(basename "$0") [SYNC-FROM-REPO=../${other_name}]"

declare -A repo_commit
declare -A repo_hash
for r in ${repos[*]}
do repo_commit[$r]=$(git -C "$(repo_path "$r")" rev-parse HEAD)
   test -n "${repo_commit[$r]}" || \
           fail "Repository ${r} doesn't have a valid git state."

   repo_hash[$r]=$(dir_nix_hash "$(repo_path "$r")" "${repo_commit[$r]}")
   test -n "${repo_hash[$r]}" || \
           fail "Failed to 'nix-prefetch-git' in $r"
   echo "--( $r:  git ${repo_commit[$r]} / sha256 ${repo_hash[$r]}"
done

repo_sources_pin_commit() {
        local repo=$1 sources=$2 pin=$3
        jq --arg pin "$pin" '.[$pin].rev' "$repo"/nix/${sources}.json -r
}

repo_sources_pin_hash() {
        local repo=$1 sources=$2 pin=$3
        jq --arg pin "$pin" '.[$pin].sha256' "$repo"/nix/${sources}.json -r
}

update_sources_pin() {
        local repo=$1 sources=$2 pin=$3 commit=$4 hash=$5 oldcommit oldhash

        oldcommit=$(repo_sources_pin_commit "$repo" "$sources" "$pin")
        oldhash=$(repo_sources_pin_hash     "$repo" "$sources" "$pin")
        if test "$oldcommit" != "$commit" -o "$oldhash" != "$hash"
        then sed -i "s/${oldcommit}/${commit}/" "${repo}"/nix/${sources}.json
             sed -i "s/${oldhash}/${hash}/"     "${repo}"/nix/${sources}.json
             cat <<EOF
Updated ${repo}/nix/${sources}.json pin for $pin:
  ${oldcommit} -> ${commit}
  ${oldhash} -> ${hash}
EOF
        fi
}

## Update sources.json
update_sources_pin "$this_repo" 'sources' "$other_name" \
                   "${repo_commit[$other_name]}" \
                   "${repo_hash[$other_name]}"

update_sources_pin "$this_repo" 'sources.bench' 'cardano-node' \
                   "${repo_commit['cardano-node']}" \
                   "${repo_hash['cardano-node']}"

if test -n "$stage_changes"
then git add "$this_repo"/nix/sources.json "$this_repo"/nix/sources.bench.json
fi
