#!/usr/bin/env bash
# usage: target_qc.sh SAMPLE BAM BED
set -euo pipefail
sample=$1; bam=$2; bed=$3
on=$(samtools view -c -F 0xF04 -q 20 -L "$bed" "$bam")
all=$(samtools view -c -F 0xF04 -q 20 "$bam")
samtools depth -a -b "$bed" -G 0xF04 -Q 20 -q 0 -s "$bam" | awk -v s="$sample" -v on="$on" -v all="$all" '{n++; sum+=$3; if($3>=20) c++} END{print "sample\ttarget_bases\tmean_depth\tpct_ge20x\ton_target_pct"; printf "%s\t%d\t%.1f\t%.1f\t%.1f\n", s, n, sum/n, 100*c/n, 100*on/all}'
