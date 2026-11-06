#!/bin/bash
#SBATCH --job-name=relax
#SBATCH --time=72:00:00
#SBATCH --output=logs/relax_%A_%a.out
#
# Stage 5.1 — FastRelax the chosen design into the Rosetta energy function
# before any redocking or redesign, with the starting coordinates restrained
# so the fold does not drift.
#
#   sbatch --array=1-10 --partition=$CPU_PARTITION \
#          05_rosetta_refinement/01_relax/submit_relax.sh <input.pdb>

source "$(dirname "$0")/../../lib/common.sh"

INPUT="${1:?usage: submit_relax.sh <input.pdb>}"
require_file "$INPUT"

OUT_DIR="${REFINE_DIR}/01_relax"
mkdir -p "$OUT_DIR" "$LOG_DIR"

TASK_ID="${SLURM_ARRAY_TASK_ID:-1}"

"${ROSETTA_BIN}/relax.${ROSETTA_SUFFIX}" \
    -database "$ROSETTA_DB" \
    -in:file:s "$INPUT" \
    -out:path:all "$OUT_DIR" \
    -out:suffix "_${TASK_ID}" \
    -user_tag "$TASK_ID" \
    -nstruct "$RELAX_NSTRUCT" \
    -relax:constrain_relax_to_start_coords \
    -relax:coord_constrain_sidechains \
    -relax:ramp_constraints false \
    -ex1 -ex2 -use_input_sc -flip_HNQ -no_optH false \
    -overwrite
