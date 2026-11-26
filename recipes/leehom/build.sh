#!/bin/bash
set -euxo pipefail

# The version is normally taken from git, which is not available in a tarball.
echo "#define VERSION \"${PKG_VERSION}\"" > src/version.h

# libgab calls a plain "ar", use the conda binutils one.
sed -i.bak -e 's/^\tar cr /\t$(AR) cr /' libgab/Makefile
sed -i.bak -e 's/^AR *= *ar cr/AR = $(CONDA_AR) cr/' libgab/gzstream/Makefile
# gzstream/ is on the include path: its "version" file would shadow the C++ <version> header.
mv libgab/gzstream/version libgab/gzstream/version.txt

# Use the htslib package instead of the htslib submodule (HTSLIBINC/HTSLIBLIB),
# libgab is built from the libgab submodule source (../libgab).
# Optimization flags come from conda (-march=nocona -mtune=haswell, portable);
# the AVX2 kernels are compiled with target attributes and chosen at run time.
export CONDA_AR="${AR}"
# (no -j: the Makefiles of libgab and gzstream are not safe for parallel make)
make -C src CXX="${CXX}" HTSLIBINC="${PREFIX}/include" HTSLIBLIB="${PREFIX}/lib" all fuzz_kernels bamview

# Upstream regression tests (md5 of the logs, SIMD kernels against the scalar
# code, thread invariance, fastq to BAM, keepOrig and QC failed flag).
(cd test && bash test.sh)

install -d "${PREFIX}/bin"
install -m 0755 src/leeHom "${PREFIX}/bin/"
