#!/usr/bin/env bash
# Test the STAGE1_PSAR_DIR start (GENERATE_QSP onwards) on the two demo liver runs.
#
#   ./run_test.sh --dry                     # no Spectronaut or licence needed; about a minute
#   ./run_test.sh --real [--with-full]      # real searches; see README.md for the inputs it needs
#
# Each scenario runs in runs/<mode>/<scenario>/ (or --out DIR) and is checked from the Nextflow trace
# and the work folders. Exit status is 0 only if every scenario passes.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
MAIN_NF=$(cd "$HERE/../.." && pwd)/main.nf
G=C_D160626_S313-liver-G-040min_MHRM_R01_T0
I=C_D160626_S313-liver-I-040min_MHRM_R01_T0

MODE=""; WITH_FULL=0; OUT=""
while (($#)); do
	case $1 in
		--dry) MODE=dry ;;
		--real) MODE=real ;;
		--with-full) WITH_FULL=1 ;;
		--out) OUT=$2; shift ;;
		-h|--help) sed -n '2,9p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done
[[ -n $MODE ]] || { echo "choose --dry or --real" >&2; exit 2; }
OUT=${OUT:-$HERE/runs/$MODE}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)

die() { echo "ERROR: $*" >&2; exit 2; }

# ---------------------------------------------------------------- inputs
if [[ $MODE == dry ]]; then
	IN=$OUT/inputs; rm -rf "$IN"; mkdir -p "$IN/raw" "$IN/stage1"
	for r in $G $I; do : > "$IN/raw/$r.raw"; echo stage1 > "$IN/stage1/$r.psar"; done
	echo "dry-run placeholder" > "$IN/license.txt"; : > "$IN/search.bgsfasta"
	RAW_DIR=$IN/raw; STAGE1_PSAR_DIR=$IN/stage1; LICENSE=$IN/license.txt; FASTA=$IN/search.bgsfasta
	SPEC_BIN=SpectronautCMD.dll
	export PATH=$HERE/fakebin:$PATH
	MODE_CONFIG=$HERE/dry.config
	WITH_FULL=1
else
	: "${RAW_DIR:?set RAW_DIR to the folder holding $G.raw and $I.raw}"
	: "${FASTA:?set FASTA to the .bgsfasta to search}"
	: "${LICENSE:?set LICENSE to a file whose first line is the Spectronaut licence key}"
	SPEC_BIN=${SPEC_BIN:-/usr/lib/spectronaut/SpectronautCMD.dll}
	for r in $G $I; do [[ -s $RAW_DIR/$r.raw ]] || die "missing $RAW_DIR/$r.raw"; done
	[[ -s $FASTA ]] || die "missing $FASTA"; [[ -s $LICENSE ]] || die "missing $LICENSE"
	if [[ $WITH_FULL == 0 ]]; then
		: "${STAGE1_PSAR_DIR:?set STAGE1_PSAR_DIR to a folder with $G.psar and $I.psar, or pass --with-full}"
	fi
	MODE_CONFIG=$HERE/real.config
fi

# ---------------------------------------------------------------- helpers
FAILS=0
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; FAILS=$((FAILS + 1)); }
expect() { # expect <description> <actual> <expected>
	if [[ $2 == "$3" ]]; then pass "$1 ($2)"; else fail "$1: got '$2', expected '$3'"; fi
}

# run_nf <scenario> <raw dir> [nextflow args...]: runs the pipeline in $OUT/<scenario>, returns its exit status
run_nf() {
	local name=$1 raw=$2; shift 2
	local d=$OUT/$name
	rm -rf "$d"; mkdir -p "$d"
	echo "== $name"
	( cd "$d" && FAKE_LOG=$d/calls.txt nextflow run "$MAIN_NF" -ansi-log false \
		-params-file "$HERE/params.yaml" -c "$HERE/test.config" -c "$MODE_CONFIG" \
		--JOB_NAME "demo_liver_$name" --spec_bin "$SPEC_BIN" --license "$LICENSE" --FASTA "$FASTA" \
		--rawfile_dir "$raw" \
		"$@" > nextflow.out 2>&1 )
}

trace() { echo "$OUT/$1/logs/trace.txt"; }
# n_tasks <scenario> <name prefix>: completed tasks whose name starts with the prefix
n_tasks() {
	local t; t=$(trace "$1"); [[ -f $t ]] || { echo 0; return; }
	awk -F'\t' -v p="$2" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i; next}
		index($c["name"],p)==1 && $c["status"]=="COMPLETED"{n++} END{print n+0}' "$t"
}
# staged <scenario> <process> <folder>: sorted names of the files a task was given in <folder>
staged() {
	local w; w=$(awk -F'\t' -v p="$2" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i; next}
		$c["name"]==p{print $c["workdir"]}' "$(trace "$1")" 2>/dev/null | tail -1)
	[[ -n $w && -d $w/$3 ]] && ls "$w/$3" | sort | paste -sd' ' || echo "(none)"
}
reads_from() { # reads_from <scenario> <process> <folder>: did the Spectronaut call use -sad <folder>?
	local w; w=$(awk -F'\t' -v p="$2" 'NR==1{for(i=1;i<=NF;i++)c[$i]=i; next}
		$c["name"]==p{print $c["workdir"]}' "$(trace "$1")" 2>/dev/null | tail -1)
	grep -q -- "-sad $3" "$w/.command.sh" 2>/dev/null && echo yes || echo no
}
outputs_ok() { # real mode only: library kit and merged .sne exist
	[[ $MODE == real ]] || return 0
	local d=$OUT/$1
	expect "library kit written" "$(ls "$d"/out_lib/libs/*.kit 2>/dev/null | wc -l | tr -d ' ')" 1
	expect "merged .sne written" "$(find "$d/out_dia" -name '*.sne' 2>/dev/null | grep -c "demo_liver_$1")" 1
}
# run_counts <scenario>: the "RUN COUNT <what>: <found> of <expected>" lines the tasks printed
run_counts() { cat "$OUT/$1"/work/*/*/.command.out 2>/dev/null | grep '^RUN COUNT' | sort; }
# counts_all <scenario> <value>: "yes" if there are 7 RUN COUNT lines and every one found <value>
counts_all() {
	local l; l=$(run_counts "$1")
	[[ $(grep -c . <<<"$l") == 7 ]] && ! grep -vqE ": $2 of " <<<"$l" && echo yes || { echo "no:"; echo "$l"; }
}
grep_q() { grep -q -- "$1" "$2" 2>/dev/null && echo yes || echo no; }

# ---------------------------------------------------------------- scenarios
S1_DIR=${STAGE1_PSAR_DIR:-}
if [[ $WITH_FULL == 1 ]]; then
	# full: every stage, no STAGE1_PSAR_DIR. Also checks the double-count fix (2 runs -> 2 archives).
	run_nf full "$RAW_DIR"; rc=$?
	expect "full: exit status" "$rc" 0
	expect "full: PULSAR_1_LIB tasks" "$(n_tasks full PULSAR_1_LIB)" 2
	expect "full: GENERATE_QSP reads stage1_psars/" "$(reads_from full GENERATE_QSP stage1_psars)" yes
	expect "full: GENERATE_QSP given" "$(staged full GENERATE_QSP stage1_psars)" "$G.psar $I.psar"
	expect "full: COMBINE_PSAR given 2 stage-3 archives" "$(staged full COMBINE_PSAR stage3_psars | wc -w | tr -d ' ')" 2
	expect "full: stage-1 files published to intermediates/libs/stage1" \
		"$(ls "$OUT/full/intermediates/libs/stage1" 2>/dev/null | sort | paste -sd' ')" "$G.psar $I.psar"
	expect "full: every run-count report finds 2 runs (EXPECTED_RUNS unset)" "$(counts_all full 2)" yes
	outputs_ok full
	[[ -z $S1_DIR ]] && S1_DIR=$OUT/full/intermediates/libs/stage1
fi

# from_qsp: both runs, stage 1 taken from S1_DIR. Pulsar stage 1 must not run.
run_nf from_qsp "$RAW_DIR" --STAGE1_PSAR_DIR "$S1_DIR" --EXPECTED_RUNS 2; rc=$?
expect "from_qsp: exit status" "$rc" 0
expect "from_qsp: start logged" "$(grep_q 'Starting at GENERATE_QSP' "$OUT/from_qsp/nextflow.out")" yes
expect "from_qsp: PULSAR_1_LIB tasks" "$(n_tasks from_qsp PULSAR_1_LIB)" 0
expect "from_qsp: GENERATE_QSP given" "$(staged from_qsp GENERATE_QSP stage1_psars)" "$G.psar $I.psar"
expect "from_qsp: PULSAR_3 tasks" "$(n_tasks from_qsp PULSAR_3_LIB)" 2
expect "from_qsp: COMBINE_PSAR given 2 stage-3 archives" "$(staged from_qsp COMBINE_PSAR stage3_psars | wc -w | tr -d ' ')" 2
expect "from_qsp: WORKFLOW_DIA tasks" "$(n_tasks from_qsp WORKFLOW_DIA)" 2
expect "from_qsp: MERGE_SNE tasks" "$(n_tasks from_qsp MERGE_SNE)" 1
expect "from_qsp: EXPECTED_RUNS 2 checked at launch" "$(grep_q 'EXPECTED_RUNS 2: 2 raw files' "$OUT/from_qsp/nextflow.out")" yes
expect "from_qsp: every run-count report finds 2 runs" "$(counts_all from_qsp 2)" yes
outputs_ok from_qsp

# subset: rawfile_dir holds only G; the stage-1 folder holds both. Only G may be used anywhere.
SUB=$OUT/inputs_subset_raw; rm -rf "$SUB"; mkdir -p "$SUB"
ln "$RAW_DIR/$G.raw" "$SUB/" 2>/dev/null || die "cannot hard-link $RAW_DIR/$G.raw into $SUB (different filesystem?); use --out on the same filesystem"
run_nf subset "$SUB" --STAGE1_PSAR_DIR "$S1_DIR"; rc=$?
expect "subset: exit status" "$rc" 0
expect "subset: PULSAR_1_LIB tasks" "$(n_tasks subset PULSAR_1_LIB)" 0
expect "subset: GENERATE_QSP given" "$(staged subset GENERATE_QSP stage1_psars)" "$G.psar"
expect "subset: COMBINE_PSAR given 1 stage-3 archive" "$(staged subset COMBINE_PSAR stage3_psars | wc -w | tr -d ' ')" 1
expect "subset: WORKFLOW_DIA tasks" "$(n_tasks subset WORKFLOW_DIA)" 1
expect "subset: every run-count report finds 1 run" "$(counts_all subset 1)" yes
outputs_ok subset

# missing: both runs, but the stage-1 folder lacks I. Must stop before any task, naming the run.
MISS=$OUT/inputs_stage1_missing; rm -rf "$MISS"; mkdir -p "$MISS"
ln -s "$S1_DIR/$G.psar" "$MISS/"
run_nf missing "$RAW_DIR" --STAGE1_PSAR_DIR "$MISS"; rc=$?
expect "missing: run fails" "$([[ $rc != 0 ]] && echo yes || echo no)" yes
expect "missing: error names the run" "$(grep_q "No .psar for raw file .*$I.raw" "$OUT/missing/nextflow.out")" yes
expect "missing: tasks run" "$(n_tasks missing '')" 0

# wrong_count: EXPECTED_RUNS 3 for 2 raw files. Must stop at launch, before any task.
run_nf wrong_count "$RAW_DIR" --STAGE1_PSAR_DIR "$S1_DIR" --EXPECTED_RUNS 3; rc=$?
expect "wrong_count: run fails" "$([[ $rc != 0 ]] && echo yes || echo no)" yes
expect "wrong_count: RUN_COUNT_MISMATCH reported" "$(grep_q 'RUN_COUNT_MISMATCH: 2 raw files' "$OUT/wrong_count/nextflow.out")" yes
expect "wrong_count: tasks run" "$(n_tasks wrong_count '')" 0

echo
if ((FAILS)); then echo "$FAILS check(s) FAILED. Logs: $OUT/<scenario>/nextflow.out"; exit 1; fi
echo "All checks passed. Logs: $OUT/<scenario>/nextflow.out"
