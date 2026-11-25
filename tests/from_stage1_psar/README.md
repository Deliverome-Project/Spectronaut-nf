# Example and test: `from_stage1_psar.nf`

`from_stage1_psar.nf` starts Spectronaut-nf at `GENERATE_QSP` from a list of existing Pulsar stage-1
`.psar` files, and searches only the listed runs. This folder has an offline check of the workflow and
a template for a real run.

| File | Purpose |
|---|---|
| `run_test.sh` | `preview`: offline check. `run`: real run. `check`: checks a real run's outputs. |
| `make_stage1_list.sh` | Writes `STAGE1_PSAR_LIST` from a folder of stage-1 `.psar` files. |
| `params.yaml` | Parameters for a real run, set up for the S3E12 arm D tissue example. Edit the paths for other data. |
| `stage1_psars_test.txt` | Example run list: the three S3E12 arm D tissue runs (`DT_01`–`DT_03`). |
| `local.config` | Single-host settings: no SLURM partitions, and inputs staged as hard links. |
| `s3e12_ConditionSetup_tissue_batch.tsv` | Condition setup used by `params.yaml`: all 52 S3E12 tissue runs. Copied unchanged from deliverome-analysis `analysis/sprint3/s3e12-proteome-solubilization/` at commit 13d580a4. |
| `deliverome_lean_w_filt.rs` | Report schema used by `params.yaml`, the Deliverome lean report with filters. Copied unchanged from deliverome-analysis `scratch/ellaine/spectronaut-report-schema/` at commit 13d580a4. |

## Offline check (no Spectronaut, licence or data)

```bash
./run_test.sh preview
```

This creates placeholder `.raw` and `.psar` files in a temporary folder and runs Nextflow with `-preview`,
which builds the workflow without running any tasks. It checks that:

- a good list of 3 runs is accepted, with comment and blank lines ignored, and a raw file in `rawfile_dir`
  that isn't listed is left out;
- each kind of bad list stops the run before any task starts: a run listed twice, a missing `.psar`, an
  empty `.psar`, a `.psar` with no raw file, and a list with no paths.

It takes about 30 s and ends with `PASS: preview`. Run it after any change to `from_stage1_psar.nf`.

## Real run

You need Spectronaut, a licence, the raw files, and one stage-1 `.psar` per raw file named after it
(`<run>.psar` for `<run>.raw`). `main.nf` writes these with `batch_size: 1` to
`intermediates/libs/stage1/`.

1. Put the licence key on the first line of `spectronaut_license.txt` in this folder. It is git-ignored.
2. Edit `params.yaml`: `rawfile_dir` and `FASTA`. `COND_SETUP` is set to
   `s3e12_ConditionSetup_tissue_batch.tsv` and `REPORT` to `deliverome_lean_w_filt.rs`, both in this folder.
   The condition setup lists all 52 S3E12 tissue runs; an arm search lists only some of them.
3. Set `STAGE1_PSAR_LIST`. It points to `stage1_psars_test.txt`, the S3E12 arm D tissue example, which was
   made with:

   ```bash
   ./make_stage1_list.sh /home/ssm-user/spectronaut_runs/s3e12_tissue_stage1/out '*_DT_0*'
   ```

   For other runs, write a new list the same way.

4. Check the list without running Spectronaut, then run:

   ```bash
   ./run_test.sh run -preview
   ./run_test.sh run              # add -resume to continue a failed run
   ```

5. Check the outputs:

   ```bash
   ./run_test.sh check
   ```

   This expects the QSP (`intermediates/<JOB_NAME>.qsp`), one stage-3 `.psar` per run
   (`intermediates/libs/stage3/`), the library (`out_lib/libs/<JOB_NAME>.kit`), and an `.sne` per run in
   `out_dia/`.

The run's output folders (`intermediates/`, `out_lib/`, `out_dia/`, `logs/`, `tmp/`, `work/`) are
written here and git-ignored (see the repository's root `.gitignore`).
