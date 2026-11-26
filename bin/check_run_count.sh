#!/usr/bin/env bash
# Run-count check for Spectronaut-nf steps that combine runs (GENERATE_QSP, COMBINE_PSAR, MERGE_SNE).
# Usage: check_run_count.sh "<what was counted>" <found> [<expected>] [stop|warn]
# Always prints "RUN COUNT <what>: <found> of <expected>". With an expected count (params.EXPECTED_RUNS) that
# found differs from: "stop" (default) exits 3 with RUN_COUNT_MISMATCH on stderr; "warn"
# (params.RUN_COUNT_ACTION = 'warn') prints RUN_COUNT_WARNING on stderr and continues. With none, only reports.
what=$1; found=$2; expected=${3:-}; action=${4:-stop}
echo "RUN COUNT ${what}: ${found} of ${expected:-?}"
if [[ -n $expected && $found != "$expected" ]]; then
    if [[ $action == warn ]]; then
        echo "RUN_COUNT_WARNING: ${what}: ${found}, expected ${expected} (EXPECTED_RUNS); continuing (RUN_COUNT_ACTION=warn)" >&2
        exit 0
    fi
    echo "RUN_COUNT_MISMATCH: ${what}: ${found}, expected ${expected} (EXPECTED_RUNS); stopping" >&2
    exit 3
fi
