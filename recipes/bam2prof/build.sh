#!/bin/bash
set -euxo pipefail

# The Makefile git-clones htslib, samtools and libgab into lib/. Instead:
# - htslib and libgab come from their packages;
# - samtools' libst.a (bedidx, sam_opts, sam_utils, bam.c) and headers are
#   built from the samtools release tarball in lib/samtools, against the
#   htslib package. Only libst.a is built, not samtools itself.
pushd lib/samtools
./configure --with-htslib=system --without-curses \
  CC="${CC}" CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" LDFLAGS="${LDFLAGS} -L${PREFIX}/lib"
make libst.a
popd

mkdir -p lib/libgab/gzstream
ln -s "${PREFIX}/lib/libgab/libgab.a" lib/libgab/libgab.a
ln -s "${PREFIX}/lib/libgab/gzstream/libgzstream.a" lib/libgab/gzstream/libgzstream.a

# -o: do not let make try to (re)build the libraries above.
make -C src \
  -o ../lib/libgab/libgab.a -o ../lib/libgab/gzstream/libgzstream.a \
  CXX="${CXX}" \
  CXXFLAGS="${CXXFLAGS} -std=c++11 -Wall -Wno-char-subscripts -O3 -I${PREFIX}/include/libgab -I${PREFIX}/include/libgab/gzstream -I../lib/samtools -I${PREFIX}/include -c" \
  LDLIBS="../lib/samtools/libst.a" \
  LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -lhts -lz -lpthread" \
  bam2prof

# Upstream regression tests (10 profiles compared against test/*.out_)
(cd test && bash test.sh)

install -d "${PREFIX}/bin"
install -m 0755 src/bam2prof "${PREFIX}/bin/"
