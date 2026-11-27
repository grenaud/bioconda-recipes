#!/bin/bash
# Round trip on a small made-up data set: three single-sample VCFs -> ACF,
# union, root/ancestral alleles taken from S3 (usepopsrootanc, replaceanc),
# view, index, idxstats, and the f2/f3 statistics. Used both at build
# time (build.sh) and as the package test. The upstream tests (make test)
# that download their data from Dropbox are not run.
set -euxo pipefail

{ glactools 2>&1 || true; } | grep -q "vcf2acf"

printf '1\t1000\t3\t60\t61\n' > ref.fa.fai
# sample: genotypes at positions 100 (A/G), 200 (C/T), 300 (G, monomorphic)
for s in S1:0/1:1/1 S2:0/0:0/1 S3:1/1:0/0; do
    IFS=: read -r name g100 g200 <<< "${s}"
    {
        printf '##fileformat=VCFv4.2\n##contig=<ID=1,length=1000>\n'
        printf '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n'
        printf '#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t%s\n' "${name}"
        printf '1\t100\t.\tA\tG\t50\tPASS\t.\tGT\t%s\n' "${g100}"
        printf '1\t200\t.\tC\tT\t50\tPASS\t.\tGT\t%s\n' "${g200}"
        printf '1\t300\t.\tG\t.\t50\tPASS\t.\tGT\t0/0\n'
    } > "${name}.vcf"
    glactools vcf2acf --onlyGT --allowall --fai ref.fa.fai "${name}.vcf" "${name}" > "${name}.acf.gz" 2> "${name}.log"
done

glactools union S1.acf.gz S2.acf.gz S3.acf.gz > union.acf.gz 2> union.log
glactools usepopsrootanc union.acf.gz S3 S3 > rootanc.acf.gz 2> rootanc.log
glactools replaceanc union.acf.gz rootanc.acf.gz > all.acf.gz 2> replaceanc.log
glactools view -h all.acf.gz > all.txt
cat all.txt
# REF,ALT counts per sample as given by the genotypes above, root and anc from S3
printf '#chr\tcoord\tREF,ALT\troot\tanc\tS1\tS2\tS3\n' > expected.txt
printf '1\t100\tA,G\t0,2:0\t0,2:0\t1,1:0\t2,0:0\t0,2:0\n' >> expected.txt
printf '1\t200\tC,T\t2,0:0\t2,0:0\t0,2:0\t1,1:0\t2,0:0\n' >> expected.txt
printf '1\t300\tG,N\t2,0:0\t2,0:0\t2,0:0\t2,0:0\t2,0:0\n' >> expected.txt
diff expected.txt all.txt

glactools index all.acf.gz
test -s all.acf.gz.bai
glactools idxstats all.acf.gz | grep -q "^1[[:space:]]3$"

# f2 and f3 run to completion
timeout 60 glactools compute -p f2 --noboot all.acf.gz > f2.txt 2> f2.log
timeout 60 glactools compute -p f3 --noboot all.acf.gz > f3.txt 2> f3.log
test -s f2.txt
test -s f3.txt
