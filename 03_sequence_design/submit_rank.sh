#!/bin/bash
#SBATCH --job-name=rank
#SBATCH --time=01:30:00
#SBATCH --mem=8G
#SBATCH --output=logs/rank_%j.out
#
# Stage 3b — rank all designed sequences and write the top N.
#   sbatch --partition=$CPU_PARTITION 03_sequence_design/submit_rank.sh

source "$(dirname "$0")/../lib/common.sh"

banner "Stage 3b: ranking sequences"
require_dir "$MPNN_DIR"
mkdir -p "$LOG_DIR"

python3 "${PIPELINE_HOME}/03_sequence_design/rank_designs.py" \
    --mpnn-dir "$MPNN_DIR" \
    --out-dir "${MPNN_DIR}/ranked" \
    --top-n "$MPNN_TOP_N" \
    --n-chains "$N_CHAINS"
