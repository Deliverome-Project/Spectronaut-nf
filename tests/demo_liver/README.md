# Test: `STAGE1_PSAR_DIR` and `EXPECTED_RUNS` on the demo liver runs

Checks that a run given `STAGE1_PSAR_DIR` skips Pulsar stage 1, builds the library from exactly the
runs in `rawfile_dir`, and stops with a clear error when a run has no stage-1 file. It also checks the
double-count fix (two runs give two stage-3 archives in `COMBINE_PSAR`, not four) and the `EXPECTED_RUNS`
run-count checks: every step reports the right number of runs, and a wrong count stops the run at launch.

The two runs are the demo liver acquisitions
`C_D160626_S313-liver-G-040min_MHRM_R01_T0.raw` and `C_D160626_S313-liver-I-040min_MHRM_R01_T0.raw`.

## Scenarios

| Scenario | `rawfile_dir` | `STAGE1_PSAR_DIR` | Checks |
|---|---|---|---|
| `full` | G, I | not set | 2 `PULSAR_1_LIB` tasks; `GENERATE_QSP` given G and I; `COMBINE_PSAR` given 2 archives; stage-1 files published to `intermediates/libs/stage1/`; with `EXPECTED_RUNS` unset, all 7 run-count reports find 2 |
| `from_qsp` | G, I | G, I | `EXPECTED_RUNS 2`. "Starting at GENERATE_QSP" logged; 0 `PULSAR_1_LIB` tasks; `GENERATE_QSP` given G and I; 2 stage-3 tasks; `COMBINE_PSAR` given 2 archives; 2 DIA tasks; 1 merge; launch check and all 7 run-count reports find 2 |
| `subset` | G only | G, I | 0 `PULSAR_1_LIB` tasks; `GENERATE_QSP` given G only; `COMBINE_PSAR` given 1 archive; 1 DIA task; all 7 run-count reports find 1 |
| `missing` | G, I | G only | run fails before any task; error names the I raw file |
| `wrong_count` | G, I | G, I | `EXPECTED_RUNS 3`. Run fails before any task with `RUN_COUNT_MISMATCH: 2 raw files` |

The 7 run-count reports (`RUN COUNT ...` lines in the task logs) are the files given to and the runs used
by `GENERATE_QSP`, `COMBINE_PSAR` and `MERGE_SNE` (the merge reports per-run `.sne` files and distinct runs
it was given, and rows in `RunIdentifications.tsv`).

In `--real` mode, `full`, `from_qsp` and `subset` also check that a library `.kit` and a merged `.sne`
were written.

What each task was given is read from its work folder (`stage1_psars/`, `stage3_psars/`), which is
exactly what Spectronaut's `-sad` sees.

## Dry run (no Spectronaut, no licence)

```bash
tests/demo_liver/run_test.sh --dry
```

A fake `dotnet` (`fakebin/dotnet`) stands in for Spectronaut: it writes the files each step expects
(including the result summaries the run-count checks read, counting the runs it was given) and logs every call to `runs/dry/<scenario>/calls.txt`. Placeholder raw and stage-1 files are made in
`runs/dry/inputs/`. Takes a few minutes, mostly the pipeline's random 0–100 s sleep before each DIA task.
It tests the pipeline's wiring, not Spectronaut's results.

## Real run

Needs Spectronaut, a licence and the two raw files (about 4.3 GB). Run outputs go to `runs/real/`
(several GB; use `--out DIR` on the same filesystem as the raw files, because the `subset` scenario
hard-links a raw file: Thermo's reader cannot read `.raw` files through symlinks).

```bash
export RAW_DIR=/path/to/demo        # holds the two .raw files
export FASTA=/path/to/search.bgsfasta
export LICENSE=/path/to/license.txt # first line: the licence key
# export SPEC_BIN=/usr/lib/spectronaut/SpectronautCMD.dll   # default

# Use stage-1 files from an earlier run (folder holding <run>.psar for G and I; extra files are ignored):
STAGE1_PSAR_DIR=/path/to/stage1 tests/demo_liver/run_test.sh --real
# or make them with the `full` scenario first:
tests/demo_liver/run_test.sh --real --with-full
```

Resources are set in `real.config` for a 64-CPU host (two 32-CPU tasks at once); lower them for a smaller
machine.

## Files

| File | Purpose |
|---|---|
| `run_test.sh` | Runs the scenarios and the checks; exit status 0 only if every check passes |
| `params.yaml` | Fixed parameters (`batch_size: 1`, no exclude pattern, no external `.psar`) |
| `test.config` | Local executor, hard-link staging, trace fields the checks read |
| `dry.config` / `real.config` | Per-mode resources and retry settings |
| `fakebin/dotnet` | Fake Spectronaut for `--dry` |
