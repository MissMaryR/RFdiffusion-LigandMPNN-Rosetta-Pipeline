#!/bin/bash
# ---------------------------------------------------------------------------
# Central configuration. Every stage script sources this file, so paths and
# run parameters are set in exactly one place.
#
#   cp config.sh my_config.sh   # optional: keep per-project copies
#   export PIPELINE_CONFIG=/path/to/my_config.sh
# ---------------------------------------------------------------------------

# --- Project ---------------------------------------------------------------
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/designs/my_project}"   # all outputs land here
ROUND="${ROUND:-round1}"                                   # label for this design round
RUN_DIR="${PROJECT_ROOT}/${ROUND}"

# --- Inputs ----------------------------------------------------------------
# Starting structure: scaffold protein with the ligand (and any metal) already
# placed in the intended pose. The ligand must sit in its own chain.
INPUT_PDB="${RUN_DIR}/inputs/scaffold.pdb"
LIGAND_CHAIN="Y"            # chain ID of the ligand in INPUT_PDB
LIGAND_RESNAME="LIG"        # 3-letter code of the small molecule
METAL_RESNAME=""            # e.g. CU / ZN / FE, or empty if none
LIGAND_PARAMS="${RUN_DIR}/inputs/${LIGAND_RESNAME}.params"   # Rosetta params file
CST_FILE="${RUN_DIR}/inputs/constraints.cst"                 # enzyme-design constraints

# --- Stage 1: RFdiffusion --------------------------------------------------
# Contig string defining what is kept and what is rebuilt. Example below keeps
# residues A1-A150, rebuilds a 12-residue loop, keeps A163-A260.
#   'contigmap.contigs=[A1-150/12-12/A163-260]'
RF_CONTIGS='[A1-150/12-12/A163-260]'
RF_ARRAY_SIZE=4             # number of array tasks
RF_DESIGNS_PER_TASK=250     # backbones per task (total = ARRAY_SIZE x this)

# --- Stage 3: LigandMPNN ---------------------------------------------------
# Residues opened to redesign (space-separated, chain+number).
MPNN_REDESIGN_RESIDUES="A151 A152 A153 A154 A155 A156 A157 A158 A159 A160 A161 A162"
MPNN_SEQS_PER_BACKBONE=10       # independent sampling runs per backbone
MPNN_TOP_N=5                    # how many top-ranked sequences to carry forward

# --- Stage 4: structure prediction ----------------------------------------
# Number of copies of the designed chain to fold together (1 = monomer,
# 3 = homotrimer). Copies are joined with ":" in the FASTA.
N_CHAINS=1

# --- Stage 5: Rosetta refinement ------------------------------------------
RELAX_NSTRUCT=50
DOCK_NSTRUCT=10
DOCK_ARRAY_SIZE=200
DESIGN_NSTRUCT=10
DESIGN_ARRAY_SIZE=200
# Ligand start position for the Rosetta StartFrom mover (pocket centre, Å).
LIGAND_START_XYZ="0.0 0.0 0.0"

# --- Software paths (edit for your cluster) --------------------------------
CONDA_SH="/path/to/anaconda3/etc/profile.d/conda.sh"
RFDIFFUSION_ENV="/path/to/envs/SE3nv"
RFDIFFUSION_RUN="/path/to/RFdiffusion/scripts/run_inference.py"
LIGANDMPNN_DIR="/path/to/LigandMPNN"
LIGANDMPNN_ENV="/path/to/envs/ligandmpnn_env"
COLABFOLD_BIN="/path/to/localcolabfold/colabfold-conda/bin"
ROSETTA_BIN="/path/to/rosetta/main/source/bin"
ROSETTA_DB="/path/to/rosetta/main/database"
ROSETTA_SUFFIX="default.linuxgccrelease"
PYMOL_PYTHON="python"       # a python that can `import pymol`

# --- Scheduler (SLURM) -----------------------------------------------------
GPU_PARTITION="gpu"
CPU_PARTITION="production"
GPU_GRES="gpu:1"
ACCOUNT=""                  # leave empty if your cluster does not need one
