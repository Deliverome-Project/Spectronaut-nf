#!/usr/bin/env bash
# Run-count check for Spectronaut-nf steps that combine runs (GENERATE_QSP, COMBINE_PSAR, MERGE_SNE).
# Usage: check_run_count.sh "<what was counted>" <found> [<expected>]
# Always prints "RUN COUNT <what>: <found> of <expected>". With an expected count (params.EXPECTED_RUNS),
# exits 3 with RUN_COUNT_MISMATCH on stderr if found differs; with none, only reports.
what=$1; found=$2; expected=${3:-}
echo "RUN COUNT ${what}: ${found} of ${expected:-?}"
if [[ -n $expected && $found != "$expected" ]]; then
    echo "RUN_COUNT_MISMATCH: ${what}: ${found}, expected ${expected} (EXPECTED_RUNS); stopping" >&2
    exit 3
fi
