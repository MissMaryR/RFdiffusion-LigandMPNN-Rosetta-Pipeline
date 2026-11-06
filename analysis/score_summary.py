#!/usr/bin/env python3
"""Pool Rosetta score files, apply the constraint filter, and rank.

Reads every ``score*.sc`` in a directory (one per array task), concatenates
them, discards structures whose constraint energy is above the cutoff - a
structure that has broken its catalytic geometry is not worth scoring - and
ranks what is left by total score, then by protein-ligand interface energy.

Usage:
    python score_summary.py --dir results/ [--cst-cutoff 1.0] [--top 20] \
                            [--out ranked_scores.csv]
"""

import argparse
import glob
import os

import pandas as pd


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", default=".", help="directory of .sc score files")
    p.add_argument("--cst-cutoff", type=float, default=1.0,
                   help="maximum total constraint energy to keep (default: 1.0)")
    p.add_argument("--top", type=int, default=20, help="rows to print (default: 20)")
    p.add_argument("--out", default=None, help="optional CSV output path")
    p.add_argument("--interface-prefix", default="SR_5_interf_E_1_5",
                   help="score column holding the interface energy")
    return p.parse_args()


def load_scores(directory):
    files = sorted(glob.glob(os.path.join(directory, "score*.sc")))
    if not files:
        raise SystemExit(f"No score*.sc files found in {directory}")
    frames = []
    for path in files:
        try:
            frames.append(pd.read_csv(path, sep=r"\s+"))
        except Exception as exc:          # a truncated file from a killed job
            print(f"  skipping {os.path.basename(path)}: {exc}")
    if not frames:
        raise SystemExit("No score files could be read.")
    print(f"Read {len(frames)} score file(s) from {directory}")
    return pd.concat(frames, ignore_index=True)


def main():
    args = parse_args()
    df = load_scores(args.dir)
    print(f"Total structures: {len(df)}")

    cst_col = "all_cst" if "all_cst" in df.columns else None
    if cst_col is None:
        raise SystemExit("No 'all_cst' column - was the EnzScore filter in the protocol?")

    interface_cols = [c for c in df.columns if c.startswith(args.interface_prefix)]
    interface_col = interface_cols[0] if interface_cols else None
    if interface_col is None:
        print(f"Note: no column starting with '{args.interface_prefix}'; "
              "ranking on total_score alone.")

    for cutoff in (2.0, args.cst_cutoff):
        n = (df[cst_col] < cutoff).sum()
        print(f"Passing constraint filter < {cutoff:.2f}: {n}")

    kept = df[df[cst_col] < args.cst_cutoff].copy()
    if kept.empty:
        raise SystemExit("Nothing passed the constraint filter. Loosen --cst-cutoff "
                         "or check the constraint definitions.")

    sort_cols = ["total_score"] + ([interface_col] if interface_col else [])
    kept = kept.sort_values(sort_cols, ascending=True)

    show = ["description", "total_score", cst_col] + ([interface_col] if interface_col else [])
    print()
    print(kept[show].head(args.top).to_string(index=False))

    if args.out:
        kept.to_csv(args.out, index=False)
        print(f"\nWrote {args.out} ({len(kept)} rows)")


if __name__ == "__main__":
    main()
