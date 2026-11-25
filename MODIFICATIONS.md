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

## Analysis runs

Commit first, then tag each run with an annotated tag that records the upstream base:

    git tag -a analysis-YYYY-MM-DD-vN -m "base: $(git describe --tags $(git merge-base HEAD upstream/main)); <params, inputs, notes>"

Add a row below with the same base value.

| Tag | Date | Upstream base | Params / config | Notes |
|-----|------|---------------|-----------------|-------|
