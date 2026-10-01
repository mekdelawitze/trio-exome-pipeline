# Reproducible trio-exome variant calling and de novo prioritization (SFARI genes)

Work in progress. Snakemake pipeline on the GIAB Ashkenazim trio (HG002/HG003/HG004), GRCh37,
benchmarked against GIAB truth sets. Method demonstration only, not a clinical analysis.

Status: Week 3 (de novo detection and SFARI annotation done via hand-run commands; Snakemake rules and reporting notebook for Week 3 not yet built).

## Setup

Create the environment with:

    conda env create -f environment.yml

`environment.yml` lists minimum version constraints only, with no
platform-specific build strings, so it solves on macOS, Linux, or
Windows/WSL2 alike. The exact package versions conda picks may differ
slightly from what produced the results in this repository, since it is
not pinned to exact builds.

`environment.lock.txt` is an exact snapshot of every package actually
installed in the author's environment (`conda list --explicit` output),
captured on Apple Silicon macOS (`osx-arm64`). It is not portable to other
platforms as-is (`conda create --file environment.lock.txt` will fail on
Linux, Intel Mac, or Windows), but it documents precisely what produced
the results in this repository, for exact reproducibility on the same
platform or as a reference if a fresh solve from `environment.yml` ever
gives different results.
