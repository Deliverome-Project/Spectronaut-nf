#!/usr/bin/env bash
# Write a STAGE1_PSAR_LIST from the stage-1 .psar files under a folder.
# Usage: make_stage1_list.sh <psar folder> [name pattern, e.g. '*_DT_0*'] > stage1_psars.txt
# Searches the folder recursively, so both Spectronaut-nf's intermediates/libs/stage1/ and a
# per-run layout (<run>/<run>.psar) work. Paths are written absolute.
set -euo pipefail
dir=${1:?usage: make_stage1_list.sh <psar folder> [name pattern]}
pattern=${2:-*}
find "$(cd "$dir" && pwd)" -type f -name "${pattern%.psar}.psar" | sort
