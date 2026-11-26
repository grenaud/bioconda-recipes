#!/bin/bash
set -euxo pipefail

# The Makefile git-clones htslib, samtools and libgab into lib/ and builds them.
# Use the htslib and libgab packages instead: link the packaged static libgab
# where the Makefile expects it, and tell make not to rebuild it (-o).
# Nothing from samtools is used by insize (its headers are not included).
mkdir -p lib/libgab/gzstream
ln -s "${PREFIX}/lib/libgab/libgab.a" lib/libgab/libgab.a
ln -s "${PREFIX}/lib/libgab/gzstream/libgzstream.a" lib/libgab/gzstream/libgzstream.a

make -C src \
  -o ../lib/libgab/libgab.a -o ../lib/libgab/gzstream/libgzstream.a \
  CXX="${CXX}" \
  CXXFLAGS="${CXXFLAGS} -std=c++11 -Wall -O3 -I${PREFIX}/include/libgab -I${PREFIX}/include/libgab/gzstream -I${PREFIX}/include -c" \
  LDLIBS="" \
  LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -lhts -lpthread" \
  insize

# Upstream tests (10 checks on test/test.sam)
SAMTOOLS="${BUILD_PREFIX}/bin/samtools" bash test/run_tests.sh

install -d "${PREFIX}/bin"
install -m 0755 src/insize "${PREFIX}/bin/"
