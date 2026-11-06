#!/bin/bash
#SBATCH --job-name=mpnn
#SBATCH --time=72:00:00
#SBATCH --mem=32G
#SBATCH --output=logs/mpnn_%A_%a.out
#
# Stage 3a — design sequences onto the ligand-bearing backbones.
#   sbatch --array=0-$((RF_ARRAY_SIZE-1)) --partition=$GPU_PARTITION \
#          --gres=$GPU_GRES 03_sequence_design/submit_ligandmpnn.sh
#
# Each array task handles the backbones produced by the matching stage-1 task
# and samples MPNN_SEQS_PER_BACKBONE independent sequences for each one, with
# the ligand present so the pocket is designed around it.

source "$(dirname "$0")/../lib/common.sh"

banner "Stage 3a: LigandMPNN sequence design"
require_dir "$GRAFTED_DIR"
mkdir -p "$MPNN_DIR" "$LOG_DIR"

export TORCH_HOME="${LIGANDMPNN_DIR}/.cache"
load_conda "$LIGANDMPNN_ENV"

TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
LAST_INDEX=$((RF_DESIGNS_PER_TASK - 1))

cd "$LIGANDMPNN_DIR"

for index in $(seq 0 "$LAST_INDEX"); do
    name="docked_${TASK_ID}_${index}"
    pdb="${GRAFTED_DIR}/${name}.pdb"
    [[ -f "$pdb" ]] || { echo "skip (missing): $pdb"; continue; }

    for run in $(seq 1 "$MPNN_SEQS_PER_BACKBONE"); do
        python run.py \
            --model_type "ligand_mpnn" \
            --pdb_path "$pdb" \
            --out_folder "${MPNN_DIR}/${name}_run${run}" \
            --redesigned_residues "$MPNN_REDESIGN_RESIDUES"
    done
done

echo "Sequences written under ${MPNN_DIR}"
