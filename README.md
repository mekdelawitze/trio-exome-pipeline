# Trio Exome Variant Calling and De Novo Analysis

Calling and benchmarking variants on chromosome 22 in the GIAB Ashkenazim trio, followed by de novo candidate filtering and annotation against SFARI genes.

## Overview

I built this project to learn how to process trio exome sequencing data, evaluate variant calls against a reference benchmark, and investigate variants present in a child but absent from both parents' genotype calls. I was interested in how coverage, filtering thresholds, and the definition of the analysis region affected the final candidates.

The workflow uses Snakemake through variant calling and benchmarking. De novo filtering, SnpEff annotation, and the SFARI lookup were performed separately with hand-run commands.

## Data and methods

I used the Oslo University Hospital exome data for the Genome in a Bottle (GIAB) Ashkenazim trio: HG002 (son), HG003 (father), and HG004 (mother). The analysis is limited to chromosome 22 and uses the GRCh37 hs37d5 reference.

- **Read preparation:** extract chromosome 22 alignments from the public BAM files and convert paired reads back to FASTQ. Singleton reads are saved separately and are not included downstream.
- **Alignment and QC:** fastp, BWA-MEM, SAMtools duplicate marking, FastQC, and MultiQC.
- **Variant calling:** GATK HaplotypeCaller in GVCF mode, followed by joint genotyping and separate hard filters for SNPs and indels.
- **Benchmarking:** compare HG002 calls with the GIAB v4.2.1 benchmark using RTG vcfeval.
- **De novo filtering:** require a heterozygous child and homozygous-reference parents, genotype quality >=20 in all three samples, child allele balance of 0.3–0.7, and no more than one alternate read in either parent. Apply depth thresholds and exclude GIAB difficult regions.
- **Annotation:** annotate the exploratory candidate with SnpEff and check its gene against a downloaded SFARI gene list.

The original capture-kit BED was unavailable. I used merged Ensembl GRCh37.87 coding regions padded by 100 bases as a target proxy, covering 1,609,537 bases on chromosome 22. Benchmarking is restricted to the intersection of this target and GIAB confident regions. Variant calling itself covers the whole chromosome.

## Results

### Variant-call benchmarking

| Variant type | True positives | False positives | False negatives | Precision | Recall | F1 |
|---|---:|---:|---:|---:|---:|---:|
| SNPs | 1,282 | 14 | 88 | 0.989 | 0.936 | 0.962 |
| Indels | 119 | 16 | 17 | 0.882 | 0.875 | 0.878 |
| Combined | 1,401 | 30 | 105 | 0.979 | 0.930 | 0.954 |

The combined results are saved in [the benchmark summary](results/benchmark/HG002_chr22/summary.txt). The separate SNP and indel totals are recorded in [the analysis notes](docs/data-notes.md); the ROC files used to derive those rows are not currently committed.

Indels had lower precision and recall than SNPs in this analysis. These results evaluate variant calls within the benchmark regions, not the accuracy of de novo detection specifically.

### Coverage

| Sample | Mean target depth | Target bases at >=20x |
|---|---:|---:|
| HG002 | 123.4 | 90.7% |
| HG003 | 103.7 | 89.2% |
| HG004 | 114.3 | 90.1% |

Coverage uses primary, nonduplicate, QC-passing alignments with mapping quality >=20 and counts overlapping mates once. The complete QC policy and revision history are in [alignment_qc.md](docs/alignment_qc.md).

### De novo candidates

| Filtering stage | Primary analysis: DP>=10 | Sensitivity analysis: DP>=8 |
|---|---:|---:|
| PASS variants with child heterozygous and parents homozygous reference | 617 | 617 |
| Depth and genotype-quality filters | 8 | 15 |
| Child allele balance and parental alternate-read filters | 7 | 9 |
| Difficult-region exclusion | 0 | 1 |
| Restricted to the padded CDS target | 0 | 0 |

I ran the DP>=8 analysis after inspecting candidates excluded by the original depth threshold. It is a post hoc sensitivity analysis; DP>=10 remains the primary analysis.

The one surviving chromosome-wide candidate at DP>=8 was an insertion at GRCh37 22:49237169, annotated as intronic in FAM19A5. The child had 4 alternate reads out of 10, while the father and mother had depths of 9 and 15 with no alternate reads. Neither FAM19A5 nor its alias TAFA5 matched the SFARI list used in this analysis.

This candidate falls outside both the raw and padded CDS targets. Within the defined target, neither depth threshold produced a surviving de novo candidate. This does not establish that the trio has no true de novo variants.

## Limitations

This is a methods project using one benchmark trio and one chromosome, not a clinical analysis or a study of autism-associated variant enrichment. The padded CDS target is a proxy, not the original capture design.

Extracting reads by chromosome before realignment and excluding singletons changes the read population. QC results therefore describe this processed subset rather than the full original exome libraries.

GATK PossibleDeNovo agreed with all seven primary-analysis candidates before difficult-region exclusion, but it used the same genotype calls. This is a consistency check, not independent validation. The exploratory insertion has not undergone read-level inspection or experimental validation.

The amount of target sequence removed by difficult-region exclusion has not yet been quantified. A complete run from a fresh checkout and environment has also not been verified.

## Implementation notes

During development, I made the coverage filters consistent, added mapping-quality filtering and overlapping-mate handling, and regenerated the QC tables. Earlier coverage outputs are preserved under `results/qc/align/archive/`.

I also corrected the committed pedigree file, added HaplotypeCaller index dependencies, and changed benchmarking to use RTG's `--evaluation-regions`. The saved benchmark summary reflects that change.

The manual de novo and annotation stages are not yet included in the Snakemake workflow. SnpEff was run in a separate environment and is not included in `environment.yml`.

## Next steps

I would automate the de novo and annotation stages, generate filter summaries directly from their outputs, and verify the complete analysis from a clean checkout. Additional checks would cover QC edge cases, filter behavior, and the extent of difficult-region exclusion.

## Running the project

From the repository root:

```bash
conda env create -f environment.yml
conda activate trio-exome
```

Prepare the reference, indexes, target BED, GIAB truth files, evaluation regions, RTG reference format, and pedigree file using the commands in [docs/data-notes.md](docs/data-notes.md). Create `resources/truth/` before running the truth-file downloads:

```bash
mkdir -p resources/truth
```

Once those resources exist, inspect the workflow and run it:

```bash
snakemake --snakefile workflow/Snakefile --cores 4 --dry-run
snakemake --snakefile workflow/Snakefile --cores 4
```

These commands run the automated workflow through benchmarking. They do not regenerate the manual de novo, SnpEff, or SFARI results.

`environment.yml` contains a mixture of version constraints and unpinned packages. `environment.lock.txt` records package versions and builds from the Apple Silicon macOS environment using `conda list --export`; it is not a portable cross-platform lock file. Identical results across environments have not been verified.