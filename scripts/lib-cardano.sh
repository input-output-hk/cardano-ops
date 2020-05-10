#!/usr/bin/env bash
# shellcheck disable=2155

op_check_genesis_age() {
        # test $# = 3 || failusage "check-genesis-age HOST SLOTLEN K"
        local core="${1:-a}" slotlen="${2:-20}" k="${3:-2160}"
        local startTime=$(nixops ssh ${core} \
                jq .startTime $(nixops ssh ${core} \
                        jq .GenesisFile $(nixops ssh ${core} -- \
                                pgrep -al cardano-node |
                                        sed 's_.* --config \([^ ]*\) .*_\1_')))
        local now=$(date +%s)
        local age_t=$((now - startTime))
        local age_slots=$((age_t / slotlen))
        local remaining=$((k * 2 - age_slots))
        cat <<EOF
---| Genesis:  .startTime=${startTime}  now=${now}  age=${age_t}s  slotlen=${slotlen}
---|           slot age=${age_slots}  k=${k}  remaining=${remaining}
EOF
        if   test "${age_slots}" -ge $((k * 2))
        then fail "genesis is too old"
        elif test "${age_slots}" -ge $((k * 38 / 20))
        then fail "genesis is dangerously old, slots remaining: ${remaining}"
        fi
}

op_grep_msgtypes() {
        local needle="$1"; shift
        grep -hi "${needle}" "$@" | jq --slurp -c 'map (.data | if (. | has("msg")) and (.msg | has("kind")) then "\(.kind).\(.msg.kind)" else .kind end) | unique'
}

op_msgtype_timespan() {
        local type=$(echo $1 | sed 's_^.*\([^\.]*\)$_\1_'); shift
        local first=$(grep -Fhi "${type}" "$@" | sort | head -n1 | jq .at | sed 's_^.*T\(.*\)Z.*$_\1_')
        local last=$(grep  -Fhi "${type}" "$@" | sort | tail -n1 | jq .at | sed 's_^.*T\(.*\)Z.*$_\1_')
        echo "${first} - ${last}"
}

op_analyse_losses() {
        local sfrom=$(head -n1 analysis/stx_stime.2 | sed 's_^.*T\(.*\)Z.*$_\1_')
        local sto=$(tail   -n1 analysis/stx_stime.2 | sed 's_^.*T\(.*\)Z.*$_\1_')
        local lfrom=$(head -n1 analysis/rtx_stime-missing.2 | sed 's_^.*T\(.*\)Z.*$_\1_')
        local lto=$(tail   -n1 analysis/rtx_stime-missing.2 | sed 's_^.*T\(.*\)Z.*$_\1_')
        local rfrom=$(head -n1 analysis/rtx_rtime.2 | sed 's_^.*T\(.*\)Z.*$_\1_')
        local rto=$(tail   -n1 analysis/rtx_rtime.2 | sed 's_^.*T\(.*\)Z.*$_\1_')

        local txids_explorer=$(op_grep_msgtypes  txid ./node*.json | tr -d '"[]' | sed 's_,_ _g' )
        local txids_generator=$(op_grep_msgtypes txid ./generato*.json | tr -d '"[]' | sed 's_,_ _g')
        cat <<EOF
  sends:   ${sfrom} - ${sto}
  losses:  ${lfrom} - ${lto}
  recvs:   ${rfrom} - ${rto}

Message kinds mentioning 'txid':

  explorer node:  ${txids_explorer}
$(for ty in ${txids_explorer}
  do echo -e "    ${ty}:  $(op_msgtype_timespan ${ty} ./node*.json)"; done)

  generator:      ${txids_generator}
$(for ty in ${txids_generator}
  do echo -e "    ${ty}:  $(op_msgtype_timespan ${ty} ./generato*.json)"; done)
EOF
}

op_blocks() {
        nixops ssh explorer 'jq --compact-output "select (.data.kind == \"Recv\" and .data.msg.kind == \"MsgBlock\") | .data.msg" /var/lib/cardano-node/logs/*.json'
}

## Classify Tx flow messages.
## This is most useful on a file that combines logs
## from the explorer node and the generator.
op_split_benchmarking_log() {
        local log="$1"
        local dir="${log/.json/.split}"

        test -f "${log}" -a "${log}" != "${dir}" -a -n "${dir}" ||
                fail "The log (${log}) file must exist, and must end with '.json'"

        mkdir -p "${dir}"
        rm -rf ./"${dir}"/*
        pushd     "${dir}" || return
        set +e ## otherwise grep will trigger exit

        cat                      > stage00.json              < "../${log}"

        grep -v ' MsgSubmitTx '  > stage01.json              < stage00.json
        grep    ' MsgSubmitTx '  > e-fro-g.MsgSubmitTx.json  < stage00.json

        grep -v '"MsgRe\(quest\|ply\)Txs"\|"TraceTxSubmissionOutbound\(SendMsgReply\|RecvMsgRequest\)Txs"' \
                < stage01.json   > stage02.json
        grep    '"MsgRe\(quest\|ply\)Txs"\|"TraceTxSubmissionOutbound\(SendMsgReply\|RecvMsgRequest\)Txs"' \
                < stage01.json   > e-and-a.MsgRRTxs.TraceTxSubmissionOutboundSRMRRTxs.json

        grep -v '"TraceMempool\(AddedTx\|RemoveTxs\)"' \
                < stage02.json   > stage03.json
        grep    '"TraceMempool\(AddedTx\|RemoveTxs\)"' \
                < stage02.json   > e.TraceMempoolARTxs.json

        grep -v '"TraceBenchTxSubRecv"' \
                < stage03.json   > stage04.json
        grep    '"TraceBenchTxSubRecv"' \
                < stage03.json   > g-to-e.TraceBenchTxSubRecv.json

        ## Extra processing
        jq .data.message         < e-fro-g.MsgSubmitTx.json |
                sed 's_.*Recv MsgSubmitTx tx: Tx \([0-9a-f]*\) .*_\1_' |
                sort -u          > txs-init
        # grep -vFf txs-init       > noInitTxs.json      < orig.json

        cd ..
        for f in "${dir}"/*
        do wc -l "${f}"; done
        popd || return
}
