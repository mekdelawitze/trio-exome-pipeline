The data is the Oslo exome for HG002, HG003 and HG004, and the BAMs total about 27.5 GB.
Chromosome 22 is named 22, not chr22.
The reference used is human_g1k_v37_decoy (the 1000 Genomes "hs37d5" reference).
target regions are Ensembl GRCh37.87 CDS exons for chr22, padded by 100 bases and merged (3,907 regions, 1.61 Mb), used because no official capture BED was available.




## Manual setup steps (not yet wrapped in Snakemake)

Two resources have to exist before `snakemake` will run, and neither is
built by a rule in this pipeline, because they are large, one-time
downloads rather than per-sample processing steps:

- **Reference genome** (`resources/ref/hs37d5.fa` plus its BWA and
  samtools indexes). Downloaded from the 1000 Genomes phase 2 reference
  collection and verified against the sample BAM headers (contig names
  and lengths match exactly). Building the BWA index takes about 35-40
  minutes on a laptop.
- **Target BED** (`resources/chr22_cds_pad100.bed`). Built from the
  Ensembl GRCh37.87 GTF: CDS features on chr22, padded 100 bp, merged.
  This approximates the real exome capture kit's target regions, since
  the actual kit BED file was not available.

Anyone reproducing this pipeline from a fresh clone needs to obtain or
rebuild these two resources first, using the commands recorded earlier
in this file. Wrapping their construction in Snakemake rules is a
possible improvement for a later pass.

## GIAB truth set (Week 2)

Downloaded the NIST/GIAB v4.2.1 high-confidence benchmark for HG002,
GRCh37 build, from the official NCBI GIAB release folder:

- `resources/truth/HG002_GRCh37_benchmark.vcf.gz` (+ `.tbi` index) —
  expert-verified variant calls, whole genome (chromosomes 1-22).
- `resources/truth/HG002_GRCh37_benchmark.bed` — ~470K confident
  regions where that truth set can be trusted.

Verified: gzip integrity, sample column reads `HG002`, and chromosome
naming (`1`, not `chr1`) matches the reference and BAM headers used
in Week 1. Only HG003/HG004 (the parents) do not have official GIAB
truth sets released, so benchmarking (Week 2) is limited to HG002.
