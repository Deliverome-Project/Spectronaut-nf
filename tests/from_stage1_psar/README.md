# Example and test: `from_stage1_psar.nf`

`from_stage1_psar.nf` starts Spectronaut-nf at `GENERATE_QSP` from a list of existing Pulsar stage-1
`.psar` files, and searches only the listed runs. This folder has an offline check of the workflow and
a template for a real run.

| File | Purpose |
|---|---|
| `run_test.sh` | `preview`: offline check. `run`: real run. `check`: checks a real run's outputs. |
| `params.yaml` | Parameters for a real run, set up for the demo liver example. Edit the paths for other data. |
| `stage1_psars_test.txt` | Example run list: two demo liver runs (`C_D160626_S313-liver-{G,I}-040min_MHRM_R01_T0`). |
| `local.config` | Single-host settings: no SLURM partitions, and inputs staged as hard links. |

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
2. Edit `params.yaml`: `rawfile_dir`, `FASTA` (the FASTA stage 1 was run with), and optionally
   `COND_SETUP`. `REPORT` is the pipeline's `input_files/Precursor_fragment_info.rs`.
3. Set `STAGE1_PSAR_LIST`. It points to `stage1_psars_test.txt`, the demo liver example. For other
   runs, write a text file with one stage-1 `.psar` path per line, for example:

   ```bash
   find /path/to/intermediates/libs/stage1 -name '*.psar' | sort > my_runs.txt
   ```

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
