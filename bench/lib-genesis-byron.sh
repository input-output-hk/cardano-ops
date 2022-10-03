#!/usr/bin/env bash
# shellcheck disable=1091,2016

profile_byron_genesis_protocol_params() {
        jq '
          { heavyDelThd:       "300000"
          , maxBlockSize:      "641000"
          , maxHeaderSize:     "200000"
          , maxProposalSize:   "700"
          , maxTxSize:         "4096"
          , mpcThd:            "200000"
          , scriptVersion:     0
          , slotDuration:      "20000"
          , softforkRule:
            { initThd:         "900000"
            , minThd:          "600000"
            , thdDecrement:    "100000"
            }
          , txFeePolicy:
            { multiplier:      "439460"
            , summand:         "155381"
            }
          , unlockStakeEpoch:  "184467"
          , updateImplicit:    "10000"
          , updateProposalThd: "100000"
          , updateVoteThd:     "100000"
          }
        ' --null-input
}

profile_byron_genesis_cli_args() {
        jq '
          def byron_genesis_cli_args:
          [ "--k",                      10
          , "--protocol-magic",         42
          , "--secret-seed",            2718281828
          , "--total-balance",          2718281828

          , "--n-poor-addresses",       128
          , "--n-delegate-addresses",   1
          , "--delegate-share",         0.8
          , "--avvm-entry-count",       0
          , "--avvm-entry-balance",     0
          ];

          byron_genesis_cli_args
          | join(" ")
        ' --null-input --raw-output
}

profile_genesis_byron() {
        local prof=${1:-default}
        local target_dir=${2:-./keys/byron}

        local byron_params_tmpfile
        byron_params_tmpfile=$(mktemp --tmpdir)
        profile_byron_genesis_protocol_params >"$byron_params_tmpfile"

        mkdir -p "$target_dir"
        rm -rf -- ./"$target_dir"

        genesis_cli_args=(
        --genesis-output-dir         "$target_dir"
        --protocol-parameters-file   "$byron_params_tmpfile"
        --start-time                 1
        $(profile_byron_genesis_cli_args))

        cardano-cli byron genesis genesis "${genesis_cli_args[@]}"
        rm -f "$byron_params_tmpfile"
}

byron_genesis_update() {
        local start_timestamp=$1 genesis_dir=${2:-./keys/byron}

        json_file_append "$genesis_dir"/genesis.json "
          { startTime: $start_timestamp }" <<<0

        local hash_byron=$(genesis_hash_byron             "$dir/byron")
        echo -n "$hash_byron"                           > "$dir/byron"/GENHASH
}

genesis_hash_byron() {
        local genesis_dir=${1:-./keys/byron}

        cardano-cli byron genesis print-genesis-hash --genesis-json "${genesis_dir}"/genesis.json |
                tail -1
}
