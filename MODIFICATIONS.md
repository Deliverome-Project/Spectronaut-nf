# Modifications from upstream

This is a private-use fork of https://github.com/BenCollinsLab/Spectronaut-nf
(remote `upstream`). `main` mirrors upstream; all modifications live on `dev`.
Nothing here is intended to be contributed back.

List changes with:

    git log upstream/main..dev --oneline
    git diff upstream/main --stat

## Changes

| Commit | Files | What and why |
|--------|-------|--------------|
| a0991a8 | modules/SN_pulsarStages.nf, nextflow.config, CHANGELOG.md | Fix per-file Pulsar stage 1 (wrap path in `file()`) and replace the invalid `retryDelay` option so retries are delayed. |

## Analysis runs

Tag the code state of each run (`git tag analysis-YYYY-MM-DD-vN`) and record it here.

| Tag | Date | Params / config | Notes |
|-----|------|-----------------|-------|
