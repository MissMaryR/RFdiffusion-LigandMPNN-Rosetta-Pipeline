#!/bin/bash
#SBATCH --job-name=rfdiff
#SBATCH --time=72:00:00
#SBATCH --mem=16G
#SBATCH --output=logs/rfdiff_%A_%a.out
# Array size and partition are set from config.sh on the sbatch command line:
#   sbatch --array=0-$((RF_ARRAY_SIZE-1)) --partition=$GPU_PARTITION --gres=$GPU_GRES \
#          01_backbone_generation/submit_rfdiffusion.sh
#
# Stage 1 — generate backbones with RFdiffusion.
#
# A segment of the scaffold is rebuilt de novo while the rest of the fold is
# held fixed, as described by RF_CONTIGS in config.sh. Each array task writes
# RF_DESIGNS_PER_TASK backbones prefixed with its task ID, so the full set is
# <task>_<index>.pdb.

source "$(dirname "$0")/../lib/common.sh"

banner "Stage 1: RFdiffusion backbone generation"
require_file "$INPUT_PDB"
mkdir -p "$BACKBONE_DIR" "$LOG_DIR"

export DGLBACKEND=pytorch
load_conda "$RFDIFFUSION_ENV"

TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"

"$RFDIFFUSION_RUN" \
    inference.input_pdb="$INPUT_PDB" \
    inference.output_prefix="${BACKBONE_DIR}/${TASK_ID}" \
    "contigmap.contigs=${RF_CONTIGS}" \
    inference.num_designs="$RF_DESIGNS_PER_TASK"

echo "Backbones written to ${BACKBONE_DIR}"
