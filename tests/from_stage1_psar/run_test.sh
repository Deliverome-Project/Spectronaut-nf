#!/usr/bin/env bash
# Test from_stage1_psar.nf. See README.md in this folder.
#
#   ./run_test.sh preview          Offline check, no Spectronaut, licence or data needed: builds placeholder
#                                  raw and .psar files, checks that a good list builds the workflow
#                                  (nextflow -preview) and that each kind of bad list is rejected.
#   ./run_test.sh run [nf args]    Real run with params.yaml in this folder (needs Spectronaut, a licence,
#                                  raw files and stage-1 .psar files). Extra args go to nextflow, e.g. -resume.
#   ./run_test.sh check            After a real run: checks the outputs exist for every listed run.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
PIPELINE=$(cd "$HERE/../.." && pwd)/from_stage1_psar.nf
mode=${1:-preview}; shift || true

fail() { echo "FAIL: $*" >&2; exit 1; }

preview() {
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT   # global so the trap still sees it when a check exits
    mkdir -p "$T/raw" "$T/psar"
    for r in runA runB runC; do echo placeholder > "$T/raw/$r.raw"; echo placeholder > "$T/psar/$r.psar"; done
    echo placeholder > "$T/raw/runD.raw"                          # in rawfile_dir but not listed
    echo placeholder > "$T/psar/orphan.psar"                      # no raw file
    : > "$T/psar/empty.psar"                                      # empty
    cat > "$T/params.yaml" <<YAML
JOB_NAME: "preview"
spec_bin: "/usr/lib/spectronaut/SpectronautCMD.dll"
license: "PLACEHOLDER-NOT-A-KEY"
rawfile_dir: "$T/raw"
FASTA: "$PIPELINE/../input_files/uniprotkbHUMAN20240104.bgsfasta"
batch_size: 1
executor: 'local'
YAML
    nf() {  # $1 = list file; prints nextflow output, returns its exit code
        (cd "$T" && nextflow run "$PIPELINE" -params-file params.yaml -c "$HERE/local.config" \
            --STAGE1_PSAR_LIST "$1" -preview 2>&1)
    }
    local out

    printf '# comment line\n\n%s\n%s\n%s\n' "$T/psar/runA.psar" "$T/psar/runB.psar" "$T/psar/runC.psar" > "$T/good.txt"
    out=$(nf "$T/good.txt") || { echo "$out"; fail "good list did not build"; }
    grep -q "Starting at GENERATE_QSP from 3 stage-1" <<<"$out" || { echo "$out"; fail "good list: expected 3 runs"; }
    grep -q "runD" <<<"$out" && fail "good list: unlisted runD was picked up"
    echo "ok   good list (3 runs, comments and blank lines ignored, unlisted raw file ignored)"

    check_rejected() {  # $1 = name, $2 = list contents, $3 = expected message
        printf '%s\n' "$2" > "$T/bad.txt"
        if out=$(nf "$T/bad.txt"); then echo "$out"; fail "$1: was accepted"; fi
        grep -q -- "$3" <<<"$out" || { echo "$out"; fail "$1: expected '$3'"; }
        echo "ok   rejected: $1"
    }
    check_rejected "run listed twice"   "$T/psar/runA.psar"$'\n'"$T/psar/runA.psar" "runs listed more than once: runA"
    check_rejected "missing .psar"      "$T/psar/nope.psar"                         "missing or empty .psar"
    check_rejected "empty .psar"        "$T/psar/empty.psar"                        "missing or empty .psar"
    check_rejected "no raw file"        "$T/psar/orphan.psar"                       "expected exactly one raw file named orphan"
    check_rejected "empty list"         "# nothing here"                            "has no .psar paths"
    echo "PASS: preview"
}

list_file() { sed -n 's/^STAGE1_PSAR_LIST: *"\(.*\)"/\1/p' "$HERE/params.yaml"; }

run() {
    cd "$HERE"; local list; list=$(list_file)
    [[ -s spectronaut_license.txt ]] || fail "put the licence key on the first line of $HERE/spectronaut_license.txt"
    [[ -s $list ]] || fail "no run list '$list': ./make_stage1_list.sh <psar folder> [pattern] > $list"
    echo "Runs in $list: $(grep -cv -e '^#' -e '^$' "$list")"
    nextflow run "$PIPELINE" -params-file params.yaml -c local.config "$@"
}

check() {
    cd "$HERE"
    local job n; job=$(sed -n 's/^JOB_NAME: *"\(.*\)"/\1/p' params.yaml)
    n=$(grep -cv -e '^#' -e '^$' "$(list_file)")
    [[ -s intermediates/$job.qsp ]] || fail "no QSP: intermediates/$job.qsp"
    local s3; s3=$(find intermediates/libs/stage3 -name '*.psar' 2>/dev/null | wc -l)
    [[ $s3 -eq $n ]] || fail "stage-3 .psar files: $s3, expected $n"
    [[ -s out_lib/libs/$job.kit ]] || fail "no library: out_lib/libs/$job.kit"
    local sne; sne=$(find out_dia -name '*.sne' | wc -l)
    [[ $sne -ge $n ]] || fail "DIA .sne files: $sne, expected at least $n (one per run plus the merged one)"
    echo "PASS: QSP, $s3 stage-3 .psar files, library, $sne .sne files for $n runs"
}

case $mode in
    preview) preview ;;
    run) run "$@" ;;
    check) check ;;
    *) fail "unknown mode '$mode' (preview | run | check)" ;;
esac
