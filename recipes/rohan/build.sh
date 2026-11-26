#!/bin/bash
set -euxo pipefail

# The Makefiles git-clone htslib, samtools, libgab, libharu and bam2prof into
# lib/ and build them. Instead:
# - htslib, libgab, libharu and GSL come from their packages;
# - samtools' libst.a (bedidx.c and three other files) is built from the
#   samtools release tarball in lib/samtools, against the htslib package;
# - bam2prof is a run dependency (the bam2prof package), not built here.
# The repository also contains a prebuilt static bin/rohan: remove it so that
# it cannot be installed or tested by mistake.
rm -f bin/rohan

pushd lib/samtools
./configure --with-htslib=system --without-curses \
  CC="${CC}" CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" LDFLAGS="${LDFLAGS} -L${PREFIX}/lib"
make libst.a
popd

# src/Makefile links libgab's FastQObj.o and FastQParser.o as objects
mkdir -p lib/libgab
(cd lib/libgab && "${AR}" x "${PREFIX}/lib/libgab/libgab.a" FastQObj.o FastQParser.o)

# Objects through the Makefile's pattern rule (which has no library
# prerequisites), then the link of its ../bin/rohan target, against the
# shared htslib, libharu and GSL.
objs=(rohan.o PdfWriter.o Hmm.o HmmState.o DataChunk.o DataToWrite.o GenoResults.o
      PositionResult.o miscfunc.o GenomicWindows.o GenomicRange.o)
make -C src -j"${CPU_COUNT}" \
  CXX="${CXX} -std=c++11" \
  CXXFLAGS="${CXXFLAGS} -Wall -O3 -I${PREFIX}/include -I${PREFIX}/include/libgab -I${PREFIX}/include/libgab/gzstream -I../lib/samtools -MMD -MP -c" \
  "${objs[@]}"
(cd src && ${CXX} ${LDFLAGS} -o ../bin/rohan "${objs[@]}" \
  ../lib/libgab/FastQObj.o ../lib/libgab/FastQParser.o \
  "${PREFIX}/lib/libgab/libgab.a" "${PREFIX}/lib/libgab/gzstream/libgzstream.a" \
  ../lib/samtools/libst.a \
  -L"${PREFIX}/lib" -lhpdf -lhts -lgsl -lz -lpthread)

# Upstream end-to-end test (make test): simulates a diploid chromosome with a
# known heterozygosity and a known ROH, runs rohan on it and checks the
# estimates (20 checks). Needs no network.
# (rohan's progress bar goes to the log file, the checks are printed.)
make -C testData test SAMTOOLS="${BUILD_PREFIX}/bin/samtools" TESTTHREADS="${CPU_COUNT}" > rohan_test.log 2>&1 \
  || { tail -c 20000 rohan_test.log; exit 1; }
sed -n '/^output files:/,$p' rohan_test.log
make -C testData test-clean

# rohan finds its data files relative to its resolved location (../ from its
# directory) and estimateDamage.pl finds rohan in ../bin/ and bam2prof in
# ../bam2prof/ from its own, so keep the repository layout in share/rohan/.
share="${PREFIX}/share/rohan"
install -d "${share}/bin" "${share}/src" "${share}/bam2prof" "${PREFIX}/bin"
install -m 0755 bin/rohan "${share}/bin/"
cp -r deaminationProfile illuminaProf DNAprof preComputated "${share}/"
sed -e '1 s|^#!.*perl.*$|#!/usr/bin/env perl|' src/estimateDamage.pl > "${share}/src/estimateDamage.pl"
chmod 0755 "${share}/src/estimateDamage.pl"
ln -s ../../../bin/bam2prof "${share}/bam2prof/bam2prof"
ln -s ../share/rohan/src/estimateDamage.pl "${PREFIX}/bin/estimateDamage.pl"

# bin/rohan is a small wrapper rather than a symlink: rohan locates itself
# from argv[0] (libgab getCWD), which, for a bare "rohan" found on the PATH,
# resolves "rohan" against the working directory first and picks up any file
# or directory called "rohan" there. Starting it by its full path avoids that.
cat > "${PREFIX}/bin/rohan" <<'WRAPPER'
#!/bin/sh
exec "$(dirname "$(readlink -f "$0")")/../share/rohan/bin/rohan" "$@"
WRAPPER
chmod 0755 "${PREFIX}/bin/rohan"
