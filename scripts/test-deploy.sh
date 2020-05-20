#!/usr/bin/env bash

cmd="${1:-build}"; shift

CLEANUP=()
at_exit() {
        for cleanup in "${CLEANUP[@]}"
        do eval ${cleanup}; done
}
trap at_exit EXIT

nixpkgs="$(nix-build ./nix \
                     --no-out-link )"
## TODO: make the following work -- that'll improve caching:
# nixpkgs=./nix
test -n "${nixpkgs}" || { echo "ERROR:  couldn't evaluate 'nixpkgs'" >&2; exit 1; }

nixops="$(nix-build  -I nixpkgs="${nixpkgs}"    \
                     '<nixpkgs>'     -A nixops  \
                     --no-out-link)"
test -n "${nixops}" || { echo "ERROR:  couldn't evaluate 'nixops'" >&2; exit 1; }

nixexpr="$(mktemp --tmpdir deploy-XXXXXX.nix)"
CLEANUP+=("rm -f ${nixexpr}")

cat >"${nixexpr}" <<EOF
import <nixops/eval-machine-info.nix> {
        networkExprs = [
                "$(realpath deployments/cardano-aws.nix)"
                "$(realpath physical/physical-shelley-dev.nix)"
        ];
        uuid = "11111111-1111-1111-1111-111111111111";
        deploymentName = "deployme";
        args = {};
        # pluginNixExprs = [];
        checkConfigurationOptions = false; }
EOF

export NIX_PATH="nixpkgs=${nixpkgs}:nixops=${nixops}/share/nix/nixops"
NODES=(
        explorer
        # a
        # b
        # c
)
ARGS=(
        "${nixexpr}"
        --show-trace
        -A machines
        --arg names "[ $(for x in "${NODES[@]}"
                         do echo "\"$x\" "
                         done) ]"
)

case ${cmd} in
        build )        nix-build "${ARGS[@]}";;
        build-local )  nix-build "${ARGS[@]}" --arg;;
        repl )   echo -e "---\n--- dep = import ${nixexpr}\n---"
                 nix repl "${nixexpr}";;
        * ) { echo "ERROR:  valid commands:  build, repl" >&2; exit 1; };; esac
