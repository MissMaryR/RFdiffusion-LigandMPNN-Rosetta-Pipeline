#!/usr/bin/env python
"""Stage 2 - put the ligand back into every RFdiffusion backbone.

RFdiffusion returns protein backbones only, so the small molecule (and any
metal) from the starting structure has to be transplanted into each one. Every
backbone is superposed onto the reference structure, then written out together
with the reference ligand chain.

Requires PyMOL with the Python API (``import pymol``).

Usage:
    python graft_ligand.py --backbones DIR --reference REF.pdb --out DIR \
                           [--ligand-chain Y]
"""

import argparse
import os
import re

from pymol import cmd, finish_launching

# Backbone files are named <task>_<index>.pdb by stage 1.
BACKBONE_PATTERN = re.compile(r"^\d+_\d+\.pdb$")


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--backbones", required=True,
                   help="directory of RFdiffusion backbone PDBs")
    p.add_argument("--reference", required=True,
                   help="starting structure containing the ligand")
    p.add_argument("--out", required=True, help="output directory")
    p.add_argument("--ligand-chain", default="Y",
                   help="chain ID of the ligand in the reference (default: Y)")
    p.add_argument("--pattern", default=None,
                   help="regex for backbone filenames (default: <task>_<index>.pdb)")
    return p.parse_args()


def main():
    args = parse_args()
    pattern = re.compile(args.pattern) if args.pattern else BACKBONE_PATTERN
    os.makedirs(args.out, exist_ok=True)

    finish_launching(["pymol", "-qc"])  # quiet, no GUI

    cmd.load(args.reference, "reference")
    cmd.select("ligand", f"reference and chain {args.ligand_chain}")
    if cmd.count_atoms("ligand") == 0:
        raise SystemExit(
            f"No atoms in chain {args.ligand_chain} of {args.reference}. "
            "Check --ligand-chain."
        )
    cmd.create("ref_ligand", "ligand")

    n_done = 0
    for pdb_file in sorted(os.listdir(args.backbones)):
        if not pattern.match(pdb_file):
            continue
        name = os.path.splitext(pdb_file)[0]
        cmd.load(os.path.join(args.backbones, pdb_file), name)

        # Superpose the new backbone onto the reference fold, then merge it
        # with the reference ligand so the ligand lands in the same pocket.
        cmd.align(name, "reference")
        merged = f"docked_{name}"
        cmd.create(merged, f"{name} + ref_ligand")
        cmd.save(os.path.join(args.out, f"{merged}.pdb"), merged)

        cmd.delete(name)
        cmd.delete(merged)
        n_done += 1

    cmd.delete("reference")
    cmd.delete("ref_ligand")
    print(f"Grafted ligand into {n_done} backbones -> {args.out}")


if __name__ == "__main__":
    main()
