#!/bin/bash
set -euxo pipefail

{ deML 2>&1 || true; } | grep -q "Mandatory parameters"

# Three read pairs: two with the indices of RG1, one with those of RG2
# (testData/index.txt), all with high index base qualities.
q7=IIIIIII
q20=IIIIIIIIIIIIIIIIIIII
: > r1.fq; : > r2.fq; : > i1.fq; : > i2.fq
n=0
for idx in AATTCAA:CATCCGG AATTCAA:CATCCGG CGCGCAG:TCATGGT; do
    n=$((n + 1))
    printf '@read%d/1\nACGTACGTACGTACGTACGT\n+\n%s\n' "${n}" "${q20}" >> r1.fq
    printf '@read%d/2\nTGCATGCATGCATGCATGCA\n+\n%s\n' "${n}" "${q20}" >> r2.fq
    printf '@read%d\n%s\n+\n%s\n' "${n}" "${idx%:*}" "${q7}" >> i1.fq
    printf '@read%d\n%s\n+\n%s\n' "${n}" "${idx#*:}" "${q7}" >> i2.fq
done

deML -i testData/index.txt -f r1.fq -r r2.fq -if1 i1.fq -if2 i2.fq -o out -s summary.txt > deml.log 2>&1 || { cat deml.log; exit 1; }

cat summary.txt
# RG, total, ...: busybox grep has no -P, hence awk
awk -F'\t' '$1 == "RG1" && $2 == 2 { ok = 1 } END { exit !ok }' summary.txt
awk -F'\t' '$1 == "RG2" && $2 == 1 { ok = 1 } END { exit !ok }' summary.txt
test "$(gzip -dc out_RG1_r1.fq.gz | grep -c '^@read')" -eq 2
test "$(gzip -dc out_RG2_r2.fq.gz | grep -c '^@read3')" -eq 1
