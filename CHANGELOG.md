# Changelog

This file records user-facing changes identified by comparing version tags in the
[Spectronaut-nf repository](https://github.com/BenCollinsLab/Spectronaut-nf/releases).
Entries are based on repository contents and tagged commits. Older versions for which
a reliable tag-to-tag change history was not available are not reconstructed here.

## [Unreleased]

### Added
- `STAGE1_PSAR_DIR`: starts the pipeline at `GENERATE_QSP` from existing Pulsar stage-1 `.psar` files instead
  of running `PULSAR_1_LIB`. The folder holds one `<run>.psar` per raw file, named after it; each raw file in
  `rawfile_dir` is paired with its `.psar`, so pointing `rawfile_dir` at a subset of runs (for example one
  experimental arm, as hard links) searches only that subset. A missing or empty `.psar` stops the run
  before any task starts. Unset (the default), every stage runs as before.

### Fixed
- Fixed the experiment-wide library counting every raw file twice. Pulsar stages 1 and 3 published their
  `.psar` files to the same `intermediates/libs/` folder, and `COMBINE_PSAR` read that whole folder, so it
  combined the stage-1 and stage-3 archives (6 for 3 raw files). `GENERATE_QSP` now reads only the stage-1
  `.psar` files and `COMBINE_PSAR` only the stage-3 files passed to it, each staged into its task's work
  directory instead of read from the shared publish folder. This also removes a race in which a step could
  start before the previous step's files had finished copying to that folder.

### Changed
- Stage-1 and stage-3 `.psar` files are now published to `intermediates/libs/stage1/` and
  `intermediates/libs/stage3/`. In batch mode both stages name their files by task number (`1.psar`, …), so
  stage-3 files previously overwrote the stage-1 files.

## [v2.9.0]()

### Changed
- Updated the container profile to bind-mount the host user's `.config` directory into the Apptainer container.
- Simplified Docker and Apptainer command examples in the container build documentation.

### Fixed
- Fixed Pulsar Stage 1 with `batch_size: 1` (one task per raw file), which failed before Spectronaut started
  with `No signature of method: java.lang.String.getBaseName()`. `PULSAR_1_LIB` now wraps the raw-file
  path in `file()` before taking its base name.
- Restored the 5-minute wait between retries of Spectronaut tasks. `retryDelay` is not a Nextflow
  directive (ignored with a warning), so failed tasks were retried immediately; the delay is now applied
  in `errorStrategy`. A task that starts just after another Spectronaut session ends can fail with
  `No valid session token available!` and needs the wait to succeed on retry.

### Changed
- Reduced `maxRetries` for Spectronaut tasks from 50 to 4. With a 5-minute wait before each retry,
  a task that keeps failing now stops the run after about 25 minutes instead of more than 4 hours.

## [v2.8.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.8.0)

### Changed
- Reorganised the Spectronaut container build materials under `Container/`, replacing
  the earlier `Container_Image_Setup/` location.
- Updated the container build definition to install the .NET 8 SDK and a supplied
  Spectronaut Debian package.
- Updated container documentation with Apptainer/Singularity and Docker build, test,
  and conversion instructions, including notes for WSL2.
- Retained the Nextflow workflow changes from v2.7.0; `main.nf` is unchanged between
  the v2.7.0 and v2.8.0 tags.

## [v2.7.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.7.0)

### Changed
- Updated raw-file handling for Pulsar Stage 1 to use absolute paths.
- Changed the Pulsar Stage 1 output to retain the raw-file value alongside the
  generated PSAR file, and passed the raw-file path directly to Spectronaut.
- Adjusted the individual-file workflow so raw files are passed without the previous
  list-wrapping operation.
- Updated the Nextflow manifest version to `v2.7.0`.

## [v2.6.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.6.0)

### Notes
- The `v2.6.0` tag points to the same commit as `v2.5.1`; the repository contents
  are identical between these two tags.

## [v2.5.1](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.5.1)

### Fixed / Changed
- Changed the `RANDOM_SLEEP` channel to use `Channel.value(file(...))`.
- Captured the combined KIT output as a single value and passed it to the DIA search
  processes, rather than passing a collected channel.
- Changed the Pulsar Stage 1 raw-file input from a `path` input to a `val` input.
- Removed an obsolete Pulsar Stage 3 process definition.

## [v2.5.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.5.0)

### Added
- Added a `RANDOM_SLEEP` input to the DIA search processes and passed the
  `scripts/random_sleep.sh` script through the workflow.

### Changed
- Added support for grouping raw files into batches for DIA search, with batch size
  derived from the configured batch size.
- Added workflow logging for the combined KIT output and DIA batches.
- Updated raw-file channel handling and passed the random-sleep script to both
  individual-file and batch DIA search processes.

## [v2.4.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.4.0)

### Changed
- Refactored Spectronaut execution-mode selection for host and container execution.
- Added explicit checks requiring `image_path` for container mode and `spec_bin`
  for host mode.
- Selected the Spectronaut command-line DLL path according to the execution mode.
- Expanded license handling to accept either a license-file path or a license value,
  with validation for missing, non-file, and empty license files.
- Updated workflow setup and configuration alongside these changes.

## [v2.3.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.3.0)

### Added
- Added container-build materials and documentation for running Spectronaut command-line
  mode using Docker or Apptainer/Singularity.
- Added a Dockerfile and container definition files for building an image from a
  separately obtained Spectronaut `.deb` installer.
- Documented the need to provide a valid Spectronaut license and the proprietary
  installer separately.

### Changed
- Updated the Nextflow workflow and supporting modules as part of the container-related
  release.

## [v2.2.0](https://github.com/BenCollinsLab/Spectronaut-nf/releases/tag/v2.2.0)

- Baseline version for the tag-to-tag comparisons documented above. A more detailed
  entry for this release has not been added because the available comparison evidence
  does not establish its changes relative to an earlier tagged release.
