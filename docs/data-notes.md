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
