The data is the Oslo exome for HG002, HG003 and HG004, and the BAMs total about 27.5 GB.
Chromosome 22 is named 22, not chr22.
The reference used is human_g1k_v37_decoy (the 1000 Genomes "hs37d5" reference).
target regions are Ensembl GRCh37.87 CDS exons for chr22, padded by 100 bases and merged (3,907 regions, 1.61 Mb), used because no official capture BED was available.




## Manual setup steps (not yet wrapped in Snakemake)

Three resources have to exist before `snakemake` will run, and none is
built by a rule in this pipeline, because they are large, one-time
downloads/builds rather than per-sample processing steps:

- **Reference genome** (`resources/ref/hs37d5.fa` plus its BWA and
  samtools indexes):

  ```
  curl -L -o resources/ref/hs37d5.fa.gz "https://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz"
  ```

  Verified against the sample BAM headers (contig names and lengths
  match exactly), not against a published checksum, since I could not
  find an official MD5/SHA manifest for this file. Building the BWA
  index takes about 35-40 minutes on a laptop.

- **Target BED** (`resources/chr22_cds_pad100.bed`), built from the
  Ensembl GRCh37.87 GTF:

  ```
  curl -L -o resources/Homo_sapiens.GRCh37.87.chr.gtf.gz "https://ftp.ensembl.org/pub/grch37/release-87/gtf/homo_sapiens/Homo_sapiens.GRCh37.87.chr.gtf.gz"
  gzip -t resources/Homo_sapiens.GRCh37.87.chr.gtf.gz && echo "file is intact"
  gunzip -c resources/Homo_sapiens.GRCh37.87.chr.gtf.gz | awk -F'\t' '$1=="22" && $3=="CDS" {print $1"\t"$4-1"\t"$5}' > resources/chr22_cds_raw.bed
  bedtools slop -i resources/chr22_cds_raw.bed -g resources/b37.genome -b 100 | sort -k1,1 -k2,2n | bedtools merge -i - > resources/chr22_cds_pad100.bed
  ```

  `resources/b37.genome` is a chromosome-name/length file bedtools
  needs so the padding step does not run past the end of chr22. As
  with the reference, no published checksum was checked for the GTF,
  only gzip integrity and a chromosome-naming check. This approximates
  the real exome capture kit's target regions, since the actual kit
  BED file was not available.

- **RTG SDF** (`resources/ref/hs37d5.sdf`), the format `rtg vcfeval`
  needs instead of a plain FASTA:

  ```
  rtg format -o resources/ref/hs37d5.sdf resources/ref/hs37d5.fa
  ```

Anyone reproducing this pipeline from a fresh clone needs to obtain or
rebuild these three resources first, using the commands above.
Wrapping their construction in Snakemake rules is a possible
improvement for a later pass.

Checksum caveat: none of the downloads above, or the GIAB truth files
documented below, were verified against a published MD5/SHA256
checksum, only against internal consistency checks (contig
names/lengths, gzip integrity, chromosome naming). The one exception
is `resources/stratifications/GRCh37_alldifficultregions.bed.gz`
(downloaded for Week 3 de novo filtering), where I computed an MD5
(`3ac91f8951453bc80c5ff31b4224e2fd`) but had no published checksum
from GIAB to compare it against either. A corrupted or wrong-version
download of any of these files would not necessarily be caught by the
checks I actually ran.

## GIAB truth set (Week 2)

Downloaded the NIST/GIAB v4.2.1 high-confidence benchmark for HG002,
GRCh37 build, from the official NCBI GIAB release folder:

  ```
  curl -L -o resources/truth/HG002_GRCh37_benchmark.vcf.gz "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh37/HG002_GRCh37_1_22_v4.2.1_benchmark.vcf.gz"
  curl -L -o resources/truth/HG002_GRCh37_benchmark.vcf.gz.tbi "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh37/HG002_GRCh37_1_22_v4.2.1_benchmark.vcf.gz.tbi"
  curl -L -o resources/truth/HG002_GRCh37_benchmark.bed "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh37/HG002_GRCh37_1_22_v4.2.1_benchmark_noinconsistent.bed"
  ```

- `resources/truth/HG002_GRCh37_benchmark.vcf.gz` (+ `.tbi` index) —
  expert-verified variant calls, whole genome (chromosomes 1-22).
- `resources/truth/HG002_GRCh37_benchmark.bed` — ~470K confident
  regions where that truth set can be trusted.

Verified: gzip integrity, sample column reads `HG002`, and chromosome
naming (`1`, not `chr1`) matches the reference and BAM headers used
in Week 1. No published checksum was checked, see the checksum
caveat above.

The benchmark rule needs the confident regions restricted to chr22 and
overlapping the exome target, so I derived a third file from the two
above:

  ```
  bedtools intersect -a resources/truth/HG002_GRCh37_benchmark.bed -b resources/chr22_cds_pad100.bed > resources/truth/HG002_chr22_eval_regions.bed
  ```

This derived file, not anything GIAB publishes directly, is what the
benchmark rule passes to `rtg vcfeval` as `--evaluation-regions` (see
the note below about switching from `--bed-regions`). Re-deriving it
is necessary after any change to `resources/chr22_cds_pad100.bed`, to
keep the benchmark consistent with the target region it is scored
against.

Correction: GIAB does publish official high-confidence truth sets for
HG003 and HG004 as well, not only HG002. NIST's GIAB integration work
built benchmark SNP, indel, and reference calls for all three
Ashkenazim trio members together. Limiting Week 2 benchmarking to
HG002 is a scope decision I am making for this project, not something
forced by missing parental data. Benchmarking the parents against
their own truth sets would be a reasonable extension later.


## Week 2 benchmark results (chr22, HG002 vs GIAB truth)

Ran GATK HaplotypeCaller (GVCF mode) per sample, joint-genotyped the trio
with GenotypeGVCFs, and applied GATK's documented hard filters separately
for SNPs and indels. Benchmarked the filtered HG002 calls against the
GIAB v4.2.1 truth set using `rtg vcfeval`, restricted to truth-confident
regions overlapping the padded CDS BED I am using as a proxy for an
exome capture target on chr22 (3,833 regions). This is not an actual
exome kit's capture design, just coding exons with 100bp padding.

| Type   | TP   | FP | FN | Precision | Recall | F1    |
|--------|------|----|----|-----------|--------|-------|
| SNPs   | 1282 | 14 | 88 | 0.989     | 0.936  | 0.962 |
| Indels | 119  | 16 | 17 | 0.882     | 0.875  | 0.878 |

SNP and indel rows are the unfiltered (no score-threshold) totals taken
from `snp_roc.tsv.gz` and `non_snp_roc.tsv.gz` in the rtg vcfeval output
directory, since the console summary rtg prints only reports one pooled
SNP+indel row. Switching the benchmark rule from `--bed-regions` to
`--evaluation-regions` moved the indel TP count from 120 to 119 (SNPs were
unaffected), consistent with `--evaluation-regions` avoiding the
boundary-clipping artifacts that mostly affect indels, whose start/end
coordinates don't align neatly with a BED region edge.

Indel accuracy is lower than SNP accuracy, which matches the known
difficulty of indel calling (ambiguous alignment/representation around
insertions and deletions) rather than indicating a pipeline problem.

Overall hard-filter pass rate: 36,739 / 37,960 variants (96.8%) passed
all GATK hard filters on chr22 before benchmarking.


## Week 2 wrapped into Snakemake

All of Week 2 (per-sample HaplotypeCaller, combining GVCFs, joint
genotyping, splitting into SNPs/indels, hard-filtering each, merging
back together, and benchmarking with rtg vcfeval) is now written as
Snakemake rules instead of commands I ran by hand.

To check this actually worked, I had Snakemake re-run the benchmark
step and it produced the exact same result as before: TP=1401, FP=30,
FN=105, F-measure=0.9540 (1282 SNP + 119 indel TPs). Same numbers, so the rules are correct.

One note: the version of rtg vcfeval I have installed doesn't support
the --force flag, and it won't write into an output folder that already
exists. So the benchmark rule deletes the old output folder first
(rm -rf) before running rtg vcfeval, so it can be re-run safely.

## Alignment QC caveat: chr22-first extraction inflates "properly paired" rates

Reads are extracted from the original whole-genome GIAB BAM by genomic
region (`samtools view <region>` against the remote BAM URL in
`subset_bam`), which pulls in a read based on its own alignment
position without regard to where its mate landed. Any read whose mate
falls outside chr22 (or just across the region boundary) is left
behind, so its partner becomes an orphan once the region is extracted.

During BAM-to-FASTQ conversion (`bam_to_fastq`), `samtools collate` +
`samtools fastq -s` correctly detects these orphaned reads and routes
them to a separate singleton FASTQ file instead of R1/R2, but that
singleton file is never used downstream, only the paired R1/R2 reads
go into `fastp` and then alignment. Measured counts: 6,119 of
1,589,269 HG002 reads (0.39%), 4,696 of 1,327,627 HG003 reads (0.35%),
and 6,040 of 1,512,989 HG004 reads (0.40%) were orphaned this way.

As a result, `results/qc/align/{sample}.flagstat.txt` and
`{sample}.target_qc.tsv` are computed on a read population that has
already had its "would-be-improperly-paired" reads filtered out before
alignment, so "% properly paired" in flagstat is modestly inflated by
construction (under 0.5% of reads affected per sample) rather than
reflecting a cleaner-than-expected library. This does not affect the
benchmark or de novo results, which operate on the aligned/called
variants, not raw read pairing stats, but it does mean the flagstat
numbers should not be read as if they came from a true chr22-targeted
capture.grep -n "^#" docs/data-notes.md

## Week 3: De Novo Variant Detection (chr22)

### Filter funnel (DP>=10, the threshold I started with)

| Step | Candidates remaining |
|---|---|
| Child het, parents hom-ref (PASS only) | 617 |
| + depth >=10 all samples, GQ >=20 all samples | 8 |
| + child allele balance 0.3-0.7 | 7 |
| + parental alt reads <=1 | 7 |
| + region exclusion (GIAB difficult regions) | 0 |

All 7 candidates that made it through every filter except region exclusion fall inside known problematic parts of chr22. Four of them sit in the immunoglobulin lambda (IGL) locus, around 22.4 to 23.3 Mb, which is highly repetitive and a real, well documented source of mismapped reads. I have not yet broken down which specific difficult-region subcategory (segmental duplication, low-mappability, tandem repeat) accounts for each exclusion, or quantified how much chr22 territory the exclusion BED removes overall. That is an open item before I treat "zero candidates" as fully interpreted.

### Cross-check against GATK PossibleDeNovo

I ran GATK4's VariantAnnotator with the PossibleDeNovo annotation on the same joint-genotyped VCF used by my own funnel. This is not a fully independent line of evidence, since it starts from the same genotype calls and can share the same alignment or calling errors. It is better described as a second annotation method applied to the same underlying data, useful mainly as a consistency check on my filter logic. It flagged 26 sites as hiConfDeNovo and 599 as loConfDeNovo, out of 37,960 total variants.

All 7 of my DP>=10 candidates also showed up in GATK's hiConfDeNovo set. That agreement is a useful sanity check on the filter logic, but it does not measure my pipeline's sensitivity or precision on de novo calls specifically, and it does not independently establish that any of these 7 are true de novo events.

I then applied the same region exclusion filter to all 26 of GATK's hiConfDeNovo sites, not just my own 7. Five survived. I checked their genotype fields directly:

| Position | Child AD (ref,alt) | Child allele balance | Passes 0.3-0.7? | Father DP | Mother DP |
|---|---|---|---|---|---|
| 22:26706405 | 10,2 | 0.167 | No | 8 | 7 |
| 22:26706410 | 12,2 | 0.143 | No | 9 | 7 |
| 22:31485156 | 6,2 | 0.250 | No (child DP also only 8) | 8 | 7 |
| 22:45414938 | 10,2 | 0.167 | No | 9 | 14 |
| 22:49237169 | 6,4 | 0.400 | Yes | 9 | 15 |

Correction from an earlier version of this section: I originally wrote that all five were excluded from my funnel by parental depth alone. That is wrong for four of the five. Those four independently fail child allele balance as well, and one also fails child depth, so they were never close calls in the first place. Only the fifth site, 22:49237169, was blocked by depth alone: it passes every other filter (GQ 99, allele balance 0.4, zero parental alt reads) and misses DP>=10 in the father by a single read (DP=9).

### Sensitivity re-run at DP>=8

Since the father's depth was the specific, isolated blocker for the one near-miss candidate that otherwise passed cleanly, I re-ran the full funnel with the depth floor relaxed to DP>=8.

To be precise about the order this happened in: I looked at the five sites' genotype fields, including seeing that 22:49237169 had GQ 99, allele balance 0.4, and DP 9 in the father, before deciding to relax the threshold. So this is a post hoc sensitivity analysis prompted by inspecting which filter was excluding the near-miss candidates, not a threshold chosen blind to the outcome. I am keeping DP>=10 as the primary, prespecified analysis and reporting DP>=8 explicitly as a follow-up check, not a replacement.

8x is generally considered a usable depth for genotyping, though what counts as enough really depends on the variant, alignment quality, allele balance, and how much confidence a given use case requires. It also matches how GATK's PossibleDeNovo annotation runs, which does not impose a hard depth floor at all.

| Step | Candidates remaining |
|---|---|
| Child het, parents hom-ref (PASS only) | 617 |
| + depth >=8 all samples, GQ >=20 all samples | 15 |
| + child allele balance 0.3-0.7 | 9 |
| + parental alt reads <=1 | 9 |
| + region exclusion | 1 |

The final candidate is chr22:49237169, a heterozygous insertion (T to TCCCTCCAC) in the child. HG002 has DP=10, GQ=99, and an allele balance of 0.4. HG003 has DP=9 and HG004 has DP=15, both homozygous reference with zero alt reads. Note that GQ 99 belongs to the child; the parents' genotype qualities are 24 (father) and 33 (mother), solid but not as strong. This is the same site that came up as a near miss in the GATK cross-check, so both methods point to the same call, though as noted above they are not fully independent of each other.

### Interpretation

At my original, prespecified DP>=10 threshold, chr22 has zero de novo candidates. That is the primary result.

The DP>=8 sensitivity analysis, prompted by inspecting why the near-miss GATK sites were being excluded, recovers exactly one candidate that clears every other filter cleanly and is corroborated by GATK's annotation on the same data.

A few things this result does not establish on its own: that the four supporting reads in the child represent clean, uniquely-mapping evidence (I have not done read-level/IGV inspection yet); that this variant falls within the actual exome capture target rather than a called-but-off-target region (also unchecked); or that AF=0.167 in the VCF means anything about population frequency. It is simply 1 alt allele out of 6 chromosomes across this one trio, not a population statistic.

One limitation worth stating plainly: this is a sensitivity check on one chromosome with one trio. If I scale this up to the full exome, average parental coverage might look different, so I would need to revisit the depth threshold then.

A scoping note on this candidate. Variant calling on chr22 was set with `config["region"] = "22"`, so it covers the whole chromosome. It was never restricted to the padded CDS target BED, `chr22_cds_pad100.bed`. That file has only been used for coverage calculations, not as the region GATK actually called variants in.

This matters for the final candidate specifically. It falls outside both the padded and the raw CDS regions, so it sits outside the exome scope this project is meant to represent, even though it was called correctly within the broader chr22 region I processed. Within the exome scope I actually intended, the result on chr22 is zero de novo candidates, at DP>=10 and at DP>=8.
