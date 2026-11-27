#!/bin/bash
set -euxo pipefail

# The Makefile git-clones htslib, samtools, libgab and tabixpp (and re-clones
# samtools whenever htslib/libhts.so is newer than samtools/samtools.h). None
# of those rules may run here: every library target is passed to make with -o
# (treated as up to date, its rule ignored), after putting in place what the
# Makefile links from it:
# - htslib: the htslib package (headers from $PREFIX/include, linked with -lhts);
# - samtools: libst.a (bedidx.c and three other files) built from the release
#   tarball against the htslib package; samtools itself is not built;
# - tabixpp: tabix.o, the only file the Makefile builds from tabixpp, taken out
#   of the tabixpp package's libtabixpp.a, with its tabix.hpp;
# - libgab: the libgab package (libgab.a, gzstream.o out of libgzstream.a).
pushd samtools
./configure --with-htslib=system --without-curses \
  CC="${CC}" CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" LDFLAGS="${LDFLAGS} -L${PREFIX}/lib"
make libst.a
popd

mkdir -p tabixpp libgab/gzstream
(cd tabixpp && "${AR}" x "${PREFIX}/lib/libtabixpp.a" tabix.o)
ln -s "${PREFIX}/lib/libgab/libgab.a" libgab/libgab.a
(cd libgab/gzstream && "${AR}" x "${PREFIX}/lib/libgab/gzstream/libgzstream.a" gzstream.o)

# bamtools_fasta.cpp is part of the glactools repository (bamtools/src/); its
# Makefile rule calls a plain g++.
(cd bamtools/src && ${CXX} ${CXXFLAGS} -c -I. -Ishared/ -Iutils/ utils/bamtools_fasta.cpp)

prebuilt=(htslib/libhts.so htslib/libhts.a samtools/libst.a samtools/bedidx.o
          tabixpp/tabix.o libgab/libgab.a libgab/gzstream/gzstream.o
          bamtools/src/bamtools_fasta.o)
make "${prebuilt[@]/#/-o}" -j"${CPU_COUNT}" \
  CXX="${CXX} -std=c++11" \
  CXXFLAGS="${CXXFLAGS} -Wall -Wno-unused-variable -Wno-unused-but-set-variable -O3 -I${PREFIX}/include -Isamtools/ -I${PREFIX}/include/libgab -I${PREFIX}/include/libgab/gzstream -Ibamtools/src/ -c" \
  glactools.o lib/libglactools.a

# Link as the "glactools" target does, against the shared htslib
${CXX} ${LDFLAGS} -o glactools glactools.o lib/libglactools.a samtools/libst.a \
  libgab/libgab.a -L"${PREFIX}/lib" -lhts -lpthread -lm -lz

# Of the upstream tests (make test), the offline ones for "compute" run here.
# The others download their data from Dropbox and are not run. run_test.sh (also
# the package test) runs a round trip on a small made-up data set.
bash test/testCompute.sh "${SRC_DIR}/glactools"
mkdir -p build_test
(cd build_test && PATH="${SRC_DIR}:${PATH}" bash "${RECIPE_DIR}/run_test.sh")
rm -rf build_test

install -d "${PREFIX}/bin"
install -m 0755 glactools "${PREFIX}/bin/"
