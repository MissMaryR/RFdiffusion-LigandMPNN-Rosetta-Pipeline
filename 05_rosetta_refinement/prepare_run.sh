#!/bin/bash
#
# Fills the placeholders in flags.template and an XML protocol, writing a
# ready-to-run copy into the stage's working directory.
#
#   bash 05_rosetta_refinement/prepare_run.sh <dock|design>

source "$(dirname "$0")/../lib/common.sh"

STAGE="${1:?usage: prepare_run.sh <dock|design>}"
case "$STAGE" in
    dock)   SRC_DIR="02_dock";   XML="dock.xml" ;;
    design) SRC_DIR="03_design"; XML="design.xml" ;;
    *) echo "ERROR: stage must be 'dock' or 'design'" >&2; exit 1 ;;
esac

require_file "$CST_FILE"
require_file "$LIGAND_PARAMS"

WORK_DIR="${REFINE_DIR}/${SRC_DIR}"
mkdir -p "$WORK_DIR/results" "$WORK_DIR/logs"

read -r SX SY SZ <<< "$LIGAND_START_XYZ"

sed -e "s|CST_FILE_HERE|${CST_FILE}|" \
    -e "s|LIGAND_PARAMS_HERE|${LIGAND_PARAMS}|" \
    "${PIPELINE_HOME}/05_rosetta_refinement/flags.template" > "${WORK_DIR}/flags"

sed -e "s|LIGAND_CHAIN_HERE|${LIGAND_CHAIN}|g" \
    -e "s|START_X_HERE|${SX}|" \
    -e "s|START_Y_HERE|${SY}|" \
    -e "s|START_Z_HERE|${SZ}|" \
    "${PIPELINE_HOME}/05_rosetta_refinement/${SRC_DIR}/${XML}" > "${WORK_DIR}/${XML}"

echo "Prepared ${WORK_DIR}:"
echo "  flags   -> cst ${CST_FILE}, params ${LIGAND_PARAMS}"
echo "  ${XML} -> ligand chain ${LIGAND_CHAIN} at (${SX}, ${SY}, ${SZ})"
echo "Copy the input structure in as ${WORK_DIR}/input.pdb, then submit."
