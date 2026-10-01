# Alignment QC (chr22, hs37d5, BWA-MEM, duplicates marked)

Target = Ensembl GRCh37.87 CDS exons +/-100 bp, merged (1,609,537 bp). Approximation of the capture kit.

Coverage was calculated from primary, nonduplicate, QC-passing alignments with
MAPQ >=20, counting overlapping mates once and applying no additional
base-quality threshold (`samtools depth -G 0xF04 -Q 20 -q 0 -s`). The
on-target and total read counts use the same `0xF04` flag filter plus `-q 20`
for consistency. This is not exactly the read population GATK HaplotypeCaller
uses internally (for example, HaplotypeCaller's standard filters do not
explicitly exclude supplementary alignments), so this table describes
coverage under an explicit, documented QC policy, not a guarantee that these
are the same reads a variant caller would use.

| Sample | Mapped | Properly paired | Mean depth | % target >=20x | On-target |
|---|---|---|---|---|---|
| HG002 | 99.98% | 99.59% | 123.4 | 90.7% | 78.4% |
| HG003 | 99.98% | 99.65% | 103.7 | 89.2% | 78.0% |
| HG004 | 99.98% | 99.65% | 114.3 | 90.1% | 76.8% |

Note: the ~9-11% of target bases below 20x likely include exons the real kit
does not capture.

Revision history: an earlier version of this table (mean depth
167.1/139.6/155.1) computed on-target/total read counts with `-F 0xD04` but
computed depth with `samtools depth`'s own default exclude-flags
(`UNMAP,SECONDARY,QCFAIL,DUP`), an inconsistent flag set, and applied no
minimum mapping quality or overlapping-mate handling anywhere. Standardizing
all three commands to the same explicit filter (`0xF04`, MAPQ >=20,
overlapping mates counted once) dropped mean depth by about 26% and
pct>=20x by 1-2 points, while on-target rate rose slightly, consistent with
the removed reads being disproportionately low-confidence or multi-mapped
rather than uniformly distributed. The original per-sample TSVs are
preserved at `results/qc/align/archive/*.v1_pre-flagfix.tsv` for reference.
