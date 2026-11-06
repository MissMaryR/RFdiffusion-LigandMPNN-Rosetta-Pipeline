#!/usr/bin/env python3
"""Stage 3b - rank every LigandMPNN sequence and write out the best ones.

LigandMPNN writes one FASTA per run under ``<run folder>/seqs/<name>.fa``. The
header of each designed sequence carries the scores, e.g.

    >name, id=1, T=0.1, seed=42, overall_confidence=0.73, ligand_confidence=0.81, seq_rec=0.41

This script collects every such record, ranks by overall confidence, writes a
scoreboard, and saves the top N sequences as FASTA files ready for structure
prediction. ``--n-chains`` repeats each sequence that many times, separated by
``:``, which is how a homo-oligomer is requested from AlphaFold-multimer.

No sequences are stored in this repository; they are produced at run time.
"""

import argparse
import os
import re

SCORE_RE = re.compile(r"(\w+)=([-\w.]+)")


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--mpnn-dir", required=True,
                   help="directory holding the per-run LigandMPNN output folders")
    p.add_argument("--out-dir", required=True, help="where to write the ranked results")
    p.add_argument("--top-n", type=int, default=5, help="how many to keep (default: 5)")
    p.add_argument("--n-chains", type=int, default=1,
                   help="copies of the sequence per FASTA record (default: 1)")
    p.add_argument("--sort-by", default="overall_confidence",
                   help="score field to rank on (default: overall_confidence)")
    return p.parse_args()


def read_records(fa_path):
    """Yield (scores, sequence) for each designed sequence in a FASTA file.

    The first record in a LigandMPNN FASTA is the input sequence, so it is
    skipped; designed sequences follow.
    """
    with open(fa_path) as fh:
        lines = [ln.strip() for ln in fh if ln.strip()]
    for i in range(2, len(lines) - 1, 2):   # skip the input record at 0/1
        header, seq = lines[i], lines[i + 1]
        if not header.startswith(">"):
            continue
        scores = {k: v for k, v in SCORE_RE.findall(header)}
        yield scores, seq


def main():
    args = parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    results = []
    for run_folder in sorted(os.listdir(args.mpnn_dir)):
        seqs_dir = os.path.join(args.mpnn_dir, run_folder, "seqs")
        if not os.path.isdir(seqs_dir):
            continue
        for fa_name in sorted(os.listdir(seqs_dir)):
            if not fa_name.endswith(".fa"):
                continue
            fa_path = os.path.join(seqs_dir, fa_name)
            for scores, seq in read_records(fa_path):
                if args.sort_by not in scores:
                    continue
                try:
                    key = float(scores[args.sort_by])
                except ValueError:
                    continue
                results.append((key, run_folder, scores, seq, fa_path))

    if not results:
        raise SystemExit(f"No scored sequences found under {args.mpnn_dir}")

    results.sort(key=lambda r: r[0], reverse=True)
    print(f"Collected {len(results)} sequences from {args.mpnn_dir}")

    # Scoreboard for the whole pool (scores only, no sequences).
    board = os.path.join(args.out_dir, "ranking.tsv")
    fields = ["id", "T", "seed", "overall_confidence", "ligand_confidence", "seq_rec"]
    with open(board, "w") as fh:
        fh.write("rank\trun\t" + "\t".join(fields) + "\tsource\n")
        for rank, (_, run, scores, _seq, path) in enumerate(results, start=1):
            row = [scores.get(f, "NA") for f in fields]
            fh.write(f"{rank}\t{run}\t" + "\t".join(row) + f"\t{path}\n")
    print(f"Wrote scoreboard: {board}")

    # Top N as FASTA, ready for folding.
    fasta_dir = os.path.join(args.out_dir, "top_sequences")
    os.makedirs(fasta_dir, exist_ok=True)
    for rank, (_, _run, _scores, seq, _path) in enumerate(results[: args.top_n], start=1):
        record = ":".join([seq] * max(1, args.n_chains))
        out_fa = os.path.join(fasta_dir, f"top_{rank}.fa")
        with open(out_fa, "w") as fh:
            fh.write(f">top_{rank}\n{record}\n")
        print(f"Wrote {out_fa}")


if __name__ == "__main__":
    main()
