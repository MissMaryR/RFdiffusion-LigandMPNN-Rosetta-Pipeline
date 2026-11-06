#!/bin/bash
# Shared helpers. Sourced by every stage script.

set -euo pipefail

# Locate and load the configuration.
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPELINE_CONFIG="${PIPELINE_CONFIG:-${_here}/config.sh}"

if [[ ! -f "$PIPELINE_CONFIG" ]]; then
    echo "ERROR: config not found: $PIPELINE_CONFIG" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$PIPELINE_CONFIG"

PIPELINE_HOME="$_here"

# Derived directories, created on demand by each stage.
BACKBONE_DIR="${RUN_DIR}/01_backbones"
GRAFTED_DIR="${RUN_DIR}/02_grafted"
MPNN_DIR="${RUN_DIR}/03_mpnn"
FOLD_DIR="${RUN_DIR}/04_folded"
REFINE_DIR="${RUN_DIR}/05_refined"
LOG_DIR="${RUN_DIR}/logs"

require_file() {
    [[ -f "$1" ]] || { echo "ERROR: missing required file: $1" >&2; exit 1; }
}

require_dir() {
    [[ -d "$1" ]] || { echo "ERROR: missing required directory: $1" >&2; exit 1; }
}

load_conda() {
    # shellcheck disable=SC1090
    source "$CONDA_SH"
    conda activate "$1"
}

banner() {
    echo "----------------------------------------------------------------"
    echo "  $*"
    echo "  run dir: ${RUN_DIR}"
    echo "----------------------------------------------------------------"
}
