#!/bin/bash
set -euxo pipefail

# The Makefiles use the git submodules (htslib, libgab, SimpleJSON) or clone
# them. htslib and libgab come from their packages here; src/Makefile links
# libgab's FastQObj.o and FastQParser.o as objects, so they are taken out of
# the packaged libgab.a.
mkdir -p libgab
(cd libgab && "${AR}" x "${PREFIX}/lib/libgab/libgab.a" FastQObj.o FastQParser.o)

# SimpleJSON: only the two library sources (not its demo program)
make -C SimpleJSON CC="${CXX}" CFLAGS="-c -Wall ${CXXFLAGS}" obj/JSON.o obj/JSONValue.o

make -C src \
  CXX="${CXX}" \
  HTSLIB="${PREFIX}/include" LIBGAB="${SRC_DIR}/libgab" SIMPLEJSON="${SRC_DIR}/SimpleJSON" \
  CXXFLAGS="${CXXFLAGS} -O3 -Wall -std=c++11 -pthread -I${PREFIX}/include -I${PREFIX}/include/libgab -I${PREFIX}/include/libgab/gzstream -I${SRC_DIR}/SimpleJSON/src" \
  LDFLAGS="${LDFLAGS} -pthread" \
  LDLIBS="-L${PREFIX}/lib -lhts ${PREFIX}/lib/libgab/libgab.a ${PREFIX}/lib/libgab/gzstream/libgzstream.a -lm -lz" \
  deML

# Upstream regression test: demultiplexes testData/ in BAM mode (1 and 4
# threads) and FASTQ mode and compares md5sums of the normalized output
# against testData/expected.md5. It expects htsfile in htslib/.
mkdir -p htslib
ln -s "${PREFIX}/bin/htsfile" htslib/htsfile
bash testData/runTests.sh

install -d "${PREFIX}/bin"
install -m 0755 src/deML "${PREFIX}/bin/"
