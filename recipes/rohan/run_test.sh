#!/bin/bash
set -euxo pipefail

# The default profiles must resolve inside the package (rohan finds them
# relative to its own location), also with a directory called "rohan" in the
# working directory.
mkdir rohan
{ rohan --help 2>&1 || true; } > help.txt
grep -E -A1 -- "--deam5p|--deam3p|--err|--base" help.txt | grep -o "(default: [^)]*)" | sed 's/^(default: //; s/)$//' > defaults.txt
cat defaults.txt
test "$(wc -l < defaults.txt)" -eq 4
while read -r f; do
    case "${f}" in "${PREFIX}"/share/rohan/*) ;; *) echo "default outside the package: ${f}"; exit 1 ;; esac
    test -s "${f}"
done < defaults.txt
test -s "${PREFIX}/share/rohan/preComputated/coverageprior/correctionCov_8.bin"

# estimateDamage.pl must find rohan and bam2prof
{ estimateDamage.pl 2>&1 || true; } > ed.txt
grep -q "detecting ROHan.*success" ed.txt
grep -q "detecting bam2prof.*success" ed.txt

# A short run on a small simulated diploid chromosome (200 kb, one
# heterozygous site per kb, about 6x), which also reads the pre-computed
# coverage priors.
awk -v L=200000 -v N=12000 'BEGIN {
    srand(7); b = "ACGT"
    for (i = 1; i <= L; i++) r = r substr(b, int(rand() * 4) + 1, 1)
    h = r
    for (p = 500; p <= L; p += 1000) {
        c = substr(h, p, 1); d = c
        while (d == c) d = substr(b, int(rand() * 4) + 1, 1)
        h = substr(h, 1, p - 1) d substr(h, p + 1)
    }
    print ">chrT" > "ref.fa"
    for (i = 1; i <= L; i += 60) print substr(r, i, 60) > "ref.fa"
    q = ""; for (i = 1; i <= 100; i++) q = q "I"
    print "@HD\tVN:1.6\tSO:unsorted" > "reads.sam"
    print "@SQ\tSN:chrT\tLN:" L > "reads.sam"
    print "@RG\tID:rg1\tSM:tiny" > "reads.sam"
    for (n = 1; n <= N; n++) {
        s = int(rand() * (L - 100)) + 1
        seq = (rand() < 0.5) ? substr(r, s, 100) : substr(h, s, 100)
        printf "r%d\t0\tchrT\t%d\t60\t100M\t*\t0\t0\t%s\t%s\tRG:Z:rg1\n", n, s, seq, q > "reads.sam"
    }
}'
samtools sort -o reads.bam reads.sam
samtools index reads.bam
samtools faidx ref.fa
echo chrT > autosomes.txt
rohan --size 100000 --chains 1000 --seed 42 --auto autosomes.txt -t 2 -o tiny ref.fa reads.bam > rohan.log 2>&1 || { tail -50 rohan.log; exit 1; }
cat tiny.summary.txt
for f in tiny.hEst.gz tiny.het.pdf tiny.hmm.pdf tiny.mid.hmmp.gz; do test -s "${f}"; done
# theta outside ROH: simulated 0.001
awk -F'\t' '/^Genome-wide theta outside ROH:/ { ok = ($2 > 0.0005 && $2 < 0.002) } END { exit !ok }' tiny.summary.txt
