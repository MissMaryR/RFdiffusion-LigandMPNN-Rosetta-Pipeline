#!/bin/bash
#SBATCH --job-name=fold
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --ntasks=8
#SBATCH --output=logs/fold_%j.out
#
# Folds a single FASTA with ColabFold (AlphaFold2 / AlphaFold2-multimer).
# Called once per sequence by submit_folding.sh; not usually run by hand.
#
#   sbatch fold_one.sh <input.fa> <output_dir>

source "$(dirname "$0")/../lib/common.sh"

FASTA="$1"
OUT_DIR="$2"
require_file "$FASTA"
mkdir -p "$OUT_DIR"

export PATH="${COLABFOLD_BIN}:$PATH"
colabfold_batch "$FASTA" "$OUT_DIR"
