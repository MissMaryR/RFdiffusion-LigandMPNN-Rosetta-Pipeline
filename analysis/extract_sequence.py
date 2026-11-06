#!/usr/bin/env python3
"""Pull the amino-acid sequence of one chain out of a PDB file.

Used to recover the sequence of a Rosetta output structure so it can be
ordered, folded, or compared against the design it came from.

Usage:
    python extract_sequence.py design.pdb --chain A --out design.fasta
"""

import argparse

from Bio.PDB import PDBParser
from Bio.SeqUtils import seq1


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("pdb", help="input PDB file")
    p.add_argument("--chain", default="A", help="chain to extract (default: A)")
    p.add_argument("--out", default=None, help="output FASTA (default: stdout)")
    return p.parse_args()


def chain_sequence(pdb_path, chain_id):
    structure = PDBParser(QUIET=True).get_structure("s", pdb_path)
    for model in structure:
        for chain in model:
            if chain.id != chain_id:
                continue
            # Blank hetflag == standard amino acid; drops ligands and waters.
            residues = [r for r in chain if r.get_id()[0] == " "]
            return "".join(seq1(r.get_resname()) for r in residues)
        break   # first model only
    return ""


def main():
    args = parse_args()
    seq = chain_sequence(args.pdb, args.chain)
    if not seq:
        raise SystemExit(f"Chain {args.chain} not found in {args.pdb}, "
                         "or it holds no standard residues.")

    record = f">{args.pdb}|chain_{args.chain}\n{seq}\n"
    if args.out:
        with open(args.out, "w") as fh:
            fh.write(record)
        print(f"Wrote {args.out} ({len(seq)} residues)")
    else:
        print(record, end="")


if __name__ == "__main__":
    main()
