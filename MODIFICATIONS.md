# Modifications from upstream

This is a fork of https://github.com/BenCollinsLab/Spectronaut-nf
(remote `upstream`). `main` mirrors upstream; all modifications live on `ellaine/dev`.
Nothing here is intended to be contributed back.

**Current upstream base:** `6196952` (`v2.9.0-4-g6196952`, 4 commits after v2.9.0).
Update this line whenever upstream is merged into `ellaine/dev`. Check it with:

    git describe --tags $(git merge-base ellaine/dev upstream/main)

Don't trust `version` in `nextflow.config`; upstream doesn't always bump it.

List changes with:

    git log upstream/main..ellaine/dev --oneline
    git diff upstream/main --stat

## Changes

| Commit | Files | What and why |
|--------|-------|--------------|
| a0991a8 | modules/SN_pulsarStages.nf, nextflow.config, CHANGELOG.md | Fix per-file Pulsar stage 1 (wrap path in `file()`) and adjust `retryDelay`. |
| 4ba840f | main.nf, nextflow.config, modules/SN_pulsarStages.nf, modules/combine_psar.nf, CHANGELOG.md | Add `STAGE1_PSAR_DIR` to start at `GENERATE_QSP` from existing stage-1 `.psar` files; stop `COMBINE_PSAR` counting every run twice (it read stage-1 and stage-3 archives from one shared folder); publish stage-1 and stage-3 files to separate subfolders. |
| 71c8ba1 | main.nf, nextflow.config, bin/check_run_count.sh, modules/SN_pulsarStages.nf, modules/combine_psar.nf, modules/merge_sne.nf | Add `EXPECTED_RUNS`: check the run count at launch (raw files, condition setup rows) and in `GENERATE_QSP`, `COMBINE_PSAR` and `MERGE_SNE` (runs given and runs used), stopping with `RUN_COUNT_MISMATCH` when set; Spectronaut can use fewer runs than it is given without a warning. |
| 52c221a | tests/demo_liver/, CHANGELOG.md | Add a demo liver test (dry mode with a fake Spectronaut, and real mode) of `STAGE1_PSAR_DIR`, the double-count fix and `EXPECTED_RUNS`; record `EXPECTED_RUNS` and the test in CHANGELOG. |

## Analysis runs

Commit first, then tag each run with an annotated tag that records the upstream base:

    git tag -a analysis-YYYY-MM-DD-vN -m "base: $(git describe --tags $(git merge-base HEAD upstream/main)); <params, inputs, notes>"

Add a row below with the same base value.

| Tag | Date | Upstream base | Params / config | Notes |
|-----|------|---------------|-----------------|-------|
