#!/bin/bash
#SBATCH --job-name=rosetta
#SBATCH --time=24:00:00
#SBATCH --output=logs/rosetta_%A_%a.out
#
# Runs a prepared RosettaScripts stage as a job array. Each task writes
# NSTRUCT structures with its own output suffix, so tasks never collide.
#
#   bash 05_rosetta_refinement/prepare_run.sh design
#   cp relaxed_best.pdb $RUN_DIR/05_refined/03_design/input.pdb
#   sbatch --array=1-200 --partition=$CPU_PARTITION \
#          05_rosetta_refinement/submit_rosetta.sh design

source "$(dirname "$0")/../lib/common.sh"

STAGE="${1:?usage: submit_rosetta.sh <dock|design>}"
case "$STAGE" in
    dock)   WORK_DIR="${REFINE_DIR}/02_dock";   XML="dock.xml";   NSTRUCT="$DOCK_NSTRUCT" ;;
    design) WORK_DIR="${REFINE_DIR}/03_design"; XML="design.xml"; NSTRUCT="$DESIGN_NSTRUCT" ;;
    *) echo "ERROR: stage must be 'dock' or 'design'" >&2; exit 1 ;;
esac

require_dir "$WORK_DIR"
require_file "${WORK_DIR}/flags"
require_file "${WORK_DIR}/${XML}"
require_file "${WORK_DIR}/input.pdb"

TASK_ID="${SLURM_ARRAY_TASK_ID:-1}"
cd "$WORK_DIR"

"${ROSETTA_BIN}/rosetta_scripts.${ROSETTA_SUFFIX}" \
    -database "$ROSETTA_DB" \
    @flags \
    -parser:protocol "$XML" \
    -s input.pdb \
    -out:path:all results/ \
    -nstruct "$NSTRUCT" \
    -user_tag "$TASK_ID" \
    -out:suffix "_${TASK_ID}" \
    -overwrite
