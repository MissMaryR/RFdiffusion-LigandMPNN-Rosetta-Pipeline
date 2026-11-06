#!/bin/bash
#SBATCH --job-name=graft
#SBATCH --time=04:00:00
#SBATCH --mem=16G
#SBATCH --output=logs/graft_%j.out
#
# Stage 2 — graft the ligand into every generated backbone.
#   sbatch --partition=$CPU_PARTITION 02_ligand_grafting/submit_graft.sh

source "$(dirname "$0")/../lib/common.sh"

banner "Stage 2: ligand grafting"
require_dir "$BACKBONE_DIR"
require_file "$INPUT_PDB"
mkdir -p "$GRAFTED_DIR" "$LOG_DIR"

load_conda "$RFDIFFUSION_ENV"   # or any env with the PyMOL Python API

"$PYMOL_PYTHON" "${PIPELINE_HOME}/02_ligand_grafting/graft_ligand.py" \
    --backbones "$BACKBONE_DIR" \
    --reference "$INPUT_PDB" \
    --out "$GRAFTED_DIR" \
    --ligand-chain "$LIGAND_CHAIN"
