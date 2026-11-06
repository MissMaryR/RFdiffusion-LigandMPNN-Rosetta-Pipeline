#!/bin/bash
#
# Stage 4 — fold each top-ranked sequence and check that it predicts to the
# intended structure. Multi-chain records (N_CHAINS > 1) are handled by
# AlphaFold2-multimer automatically.
#
# Run this from a login node; it submits one GPU job per sequence:
#   bash 04_structure_prediction/submit_folding.sh

source "$(dirname "$0")/../lib/common.sh"

banner "Stage 4: structure prediction"
FASTA_DIR="${MPNN_DIR}/ranked/top_sequences"
require_dir "$FASTA_DIR"
mkdir -p "$FOLD_DIR" "$LOG_DIR"

submitted=0
for rank in $(seq 1 "$MPNN_TOP_N"); do
    fasta="${FASTA_DIR}/top_${rank}.fa"
    if [[ ! -f "$fasta" ]]; then
        echo "WARNING: no such file, skipping: $fasta" >&2
        continue
    fi
    sbatch --partition="$GPU_PARTITION" --gres="$GPU_GRES" \
        "${PIPELINE_HOME}/04_structure_prediction/fold_one.sh" \
        "$fasta" "${FOLD_DIR}/top_${rank}"
    submitted=$((submitted + 1))
done

echo "Submitted ${submitted} folding job(s); results under ${FOLD_DIR}"
