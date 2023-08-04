#!/usr/bin/env bash
# shellcheck disable=2155

# deploystate_check_node_log_commit_id
node_wait_for_commit_id() {
        local mach=$1 expected=$2 actual=

        oprint_ne "checking node commit on $mach:  "
        while actual=$(node_runtime_log_commit_id "$mach");
              test -z "$actual"
        do sleep 1; echo -n '.'; done

        if test "$expected" != "$actual"
        then # In normal operation, this should be a fatal error.
             # fail " expected $expected, got $actual"
             # This is a workaround for 8.2.0-pre not providing
             # correct commit ID tags for trace messages.
             msg "WARNING: expected $expected, got $actual"
        else msg " ok, $expected"; fi
}
