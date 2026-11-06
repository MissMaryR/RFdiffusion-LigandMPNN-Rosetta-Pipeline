# Computational enzyme-design pipeline

Scripts for designing a small-molecule-converting enzyme on a fixed scaffold:
generate backbones, design sequences around the ligand, check that they fold,
then refine the active site in Rosetta.

This repository is the **method**, not a dataset. It contains no designed
sequences, no structures, and no results — those are produced when the pipeline
is run. Everything specific to a given project (scaffold, ligand, which
residues are rebuilt, where the software lives) is set in [`config.sh`](config.sh).

The pipeline accompanies a manuscript describing its application to a
copper-dependent phenol-oxidizing enzyme; it is written to be reusable for any
ligand-binding enzyme-design problem of the same shape.

---

## The idea

A scaffold protein already binds the cofactor and has roughly the right fold,
but its active site does not do the chemistry of interest. Rather than mutate
positions one at a time, the pipeline rebuilds a chosen region of the backbone
thousands of times, designs sequences into each rebuilt pocket with the
substrate physically present, and keeps only the designs that fold back to the
intended structure. A final Rosetta round polishes the best candidate's active
site against explicit catalytic geometry.

Each stage narrows the pool: thousands of backbones → tens of thousands of
sequences → a handful that fold → one or two refined designs worth testing.

```
scaffold + ligand
      │
 [1]  ├─ RFdiffusion ─────────── backbones with a rebuilt region
      │
 [2]  ├─ PyMOL ───────────────── ligand grafted back into each backbone
      │
 [3]  ├─ LigandMPNN ──────────── sequences designed around the ligand
      │                          ranked by confidence → top N
 [4]  ├─ ColabFold / AF2 ─────── fold check: does it predict as intended?
      │
 [5]  └─ Rosetta ─────────────── relax → redock → active-site redesign
                                 → final design(s)
```

---

## Stages

| # | Stage | Directory | Tool | Produces |
|---|-------|-----------|------|----------|
| 1 | Backbone generation | `01_backbone_generation/` | RFdiffusion | backbone PDBs with the chosen region rebuilt |
| 2 | Ligand grafting | `02_ligand_grafting/` | PyMOL | each backbone with the ligand (and metal) in place |
| 3 | Sequence design | `03_sequence_design/` | LigandMPNN | designed sequences, ranked; top N as FASTA |
| 4 | Structure prediction | `04_structure_prediction/` | ColabFold (AlphaFold2 / -multimer) | predicted structures + confidence metrics |
| 5 | Refinement | `05_rosetta_refinement/` | Rosetta | relaxed, redocked, redesigned structures |
| — | Analysis | `analysis/` | pandas, Biopython | score tables, extracted sequences |

**1 — Backbone generation.** RFdiffusion rebuilds the region named in
`RF_CONTIGS` while holding the rest of the fold fixed. The contig string is what
decides the design problem: `[A1-150/12-12/A163-260]` keeps residues 1–150,
replaces what was 151–162 with a fresh 12-residue segment, and keeps 163–260.
Run as a job array; total backbones = `RF_ARRAY_SIZE × RF_DESIGNS_PER_TASK`.

**2 — Ligand grafting.** RFdiffusion returns protein only, so the ligand has to
be put back. Each backbone is superposed onto the starting structure and written
out together with the reference ligand chain, which places the ligand in the
same pocket in every backbone.

**3 — Sequence design.** LigandMPNN designs the positions listed in
`MPNN_REDESIGN_RESIDUES` with the ligand present, so the pocket is built around
the substrate rather than around empty space. Each backbone is sampled
`MPNN_SEQS_PER_BACKBONE` times. `rank_designs.py` then pools every sequence,
ranks on the confidence reported in the FASTA header, and writes the top N.

**4 — Structure prediction.** Sequence design scores say a sequence suits a
backbone; they do not say the sequence folds to it. ColabFold folds the top
candidates from sequence alone. A design whose prediction does not match the
intended fold, or whose confidence is low, is discarded here. Set `N_CHAINS` to
fold an oligomer with AlphaFold2-multimer.

**5 — Rosetta refinement.** A second, physics-based round on the best design:

| Sub-step | Directory | What it does |
|----------|-----------|--------------|
| 5.1 relax | `05_rosetta_refinement/01_relax/` | FastRelax into the Rosetta energy function, restrained to the starting coordinates |
| 5.2 dock | `05_rosetta_refinement/02_dock/` | redock the ligand; repack and minimize, no sequence change |
| 5.3 design | `05_rosetta_refinement/03_design/` | redesign the pocket against the catalytic constraints |

Steps 5.2 and 5.3 run the same protocol with design switched off and on. Both
enforce the geometry in the constraint file, and both report a constraint
energy that `analysis/score_summary.py` uses as a hard filter: a structure that
has let its catalytic geometry slip is dropped before anything else is
considered.

---

## Requirements

Install separately; none are vendored here.

- [RFdiffusion](https://github.com/RosettaCommons/RFdiffusion) (GPU)
- [LigandMPNN](https://github.com/dauparas/LigandMPNN) (GPU)
- [LocalColabFold](https://github.com/YoshitakaMo/localcolabfold) (GPU)
- [Rosetta](https://rosettacommons.org/software/) — `relax` and `rosetta_scripts`
- PyMOL with the Python API (open-source build is fine)
- Python 3.9+ with `pandas` and `biopython`

The submission scripts target a SLURM cluster. On another scheduler, the
`#SBATCH` headers are the only part that needs rewriting — each script's body is
plain bash.

---

## Running it

```bash
git clone <this repository>
cd enzyme-design-pipeline
```

**1. Prepare inputs.** In `$RUN_DIR/inputs/`, place:

- `scaffold.pdb` — the scaffold with the ligand (and metal) already positioned
  in the intended pose, the ligand in its own chain
- `<LIGAND>.params` — Rosetta parameters for the ligand
- `constraints.cst` — catalytic geometry; start from
  [`templates/constraints.cst.template`](templates/constraints.cst.template)

**2. Edit `config.sh`.** Set the project paths, the ligand chain and residue
names, the contig string, the redesigned positions, and the software locations.
Nothing else in the repository needs editing.

**3. Run the stages.**

```bash
source config.sh

# Stage 1 - backbone generation
sbatch --array=0-$((RF_ARRAY_SIZE-1)) --partition=$GPU_PARTITION \
       --gres=$GPU_GRES 01_backbone_generation/submit_rfdiffusion.sh
```

```bash
# Stage 2 - graft the ligand into every backbone
sbatch --partition=$CPU_PARTITION 02_ligand_grafting/submit_graft.sh
```

```bash
# Stage 3 - sequence design, then ranking
sbatch --array=0-$((RF_ARRAY_SIZE-1)) --partition=$GPU_PARTITION \
       --gres=$GPU_GRES 03_sequence_design/submit_ligandmpnn.sh
```

```bash
sbatch --partition=$CPU_PARTITION 03_sequence_design/submit_rank.sh
```

```bash
# Stage 4 - fold the top-ranked sequences (submits one job each)
bash 04_structure_prediction/submit_folding.sh
```

```bash
# Stage 5.1 - relax the chosen design
sbatch --array=1-10 --partition=$CPU_PARTITION \
       05_rosetta_refinement/01_relax/submit_relax.sh best_design.pdb
```

```bash
# Stage 5.2 / 5.3 - prepare, stage the input, then submit
bash 05_rosetta_refinement/prepare_run.sh design
```

```bash
sbatch --array=1-$DESIGN_ARRAY_SIZE --partition=$CPU_PARTITION \
       05_rosetta_refinement/submit_rosetta.sh design
```

Stage 3 runs `MPNN_SEQS_PER_BACKBONE` designs on every backbone, so it is by far
the longest stage; size the array to your queue limits.

**4. Analyse.**

```bash
python analysis/score_summary.py --dir $RUN_DIR/05_refined/03_design/results --top 20
```

```bash
python analysis/extract_sequence.py best.pdb --chain A --out best.fasta
```

---

## Repository layout

```
enzyme-design-pipeline/
├── README.md
├── config.sh                        all project settings live here
├── lib/common.sh                    shared helpers, sourced by every stage
├── 01_backbone_generation/
│   └── submit_rfdiffusion.sh
├── 02_ligand_grafting/
│   ├── graft_ligand.py
│   └── submit_graft.sh
├── 03_sequence_design/
│   ├── submit_ligandmpnn.sh
│   ├── rank_designs.py
│   └── submit_rank.sh
├── 04_structure_prediction/
│   ├── fold_one.sh
│   └── submit_folding.sh
├── 05_rosetta_refinement/
│   ├── flags.template
│   ├── prepare_run.sh
│   ├── submit_rosetta.sh
│   ├── 01_relax/submit_relax.sh
│   ├── 02_dock/dock.xml
│   └── 03_design/design.xml
├── analysis/
│   ├── score_summary.py
│   └── extract_sequence.py
└── templates/
    └── constraints.cst.template
```

---

## Notes and caveats

- **Scale.** A full run is on the order of a thousand backbones and tens of
  thousands of sequences, which is days of GPU time. Reduce
  `RF_DESIGNS_PER_TASK` and `MPNN_SEQS_PER_BACKBONE` to test the plumbing first.
- **Stage 4 is the real filter.** Design scores are optimistic. The fold check
  is where most candidates fail, and it is worth folding more than five if the
  budget allows.
- **Constraints decide the outcome.** The catalytic geometry in the `.cst` file
  is what distinguishes enzyme design from binder design. Getting the atom maps
  and tolerances right matters more than any sampling parameter.
- **Metals.** `-in:auto_setup_metals` in the flags file lets Rosetta build
  metal-coordination constraints automatically; explicit constraints on the
  coordinating residues are still worth adding.
- **Computational predictions only.** Everything here produces candidates.
  Expression, folding, and activity have to be measured experimentally.
