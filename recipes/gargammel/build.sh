#!/bin/bash
set -euxo pipefail

cd "${SRC_DIR}/gargammel"

# gzstream/ is on the include path: its "version" file would shadow the C++ <version> header.
mv libgab/gzstream/version libgab/gzstream/version.txt

# bamtools from the bamtools package, in the layout the Makefiles expect
# (-I../bamtools/src, ../bamtools/build/src/libbamtools.a)
mkdir -p bamtools/build/src
ln -s "${PREFIX}/include/bamtools" bamtools/src
ln -s "${PREFIX}/lib/libbamtools.a" bamtools/build/src/libbamtools.a

# libgab, then the six programs in src/ (no -j: the libgab Makefiles are not safe for parallel make)
make -C libgab CXX="${CXX}" BAMTOOLSINC="${PREFIX}/include/bamtools" BAMTOOLSLIB="${PREFIX}/lib"
binaries=(fragSim deamSim adptSim fasta2fastas damage_patterns2prof mapDamage2prof)
make -C src CXX="${CXX}" "${binaries[@]}"

# art_illumina, patched as in the top-level Makefile of gargammel (which would
# download the tarball itself). The tarball ships stale objects and binaries,
# hence the "make clean" after configure.
pushd art_src_MountRainier_Linux
patch -p1 < ../patches/art_illumina_gargammel.patch
touch aclocal.m4 configure config.h.in Makefile.in
if [[ "${target_platform}" == "osx-arm64" ]]; then
    ./configure --prefix="${PREFIX}" --host=arm
else
    ./configure --prefix="${PREFIX}"
fi
make clean
make -j"${CPU_COUNT}" art_illumina
popd
ln -s art_src_MountRainier_Linux art_src_MountRainier

# Upstream test suite (310 checks: each tool, the patched art_illumina, the
# pipes and gargammel.pl), on the binaries in the source tree.
# LC_ALL=C: one check compares the output of "sort -u" on "+" and "-", which depends on the locale
LC_ALL=C bash tests/run_tests.sh

# The programs are installed in libexec/gargammel/ and linked from bin/:
# deamSim finds its built-in matrices (-mat single|double) in matrices/ next to
# its resolved path, and gargammel.pl finds the programs next to its own.
# art_illumina is not linked from bin/, so as not to conflict with the art package.
libexec="${PREFIX}/libexec/gargammel"
install -d "${PREFIX}/bin" "${libexec}/matrices"
for b in "${binaries[@]}"; do
    install -m 0755 "src/${b}" "${libexec}/"
    ln -s "../libexec/gargammel/${b}" "${PREFIX}/bin/${b}"
done
install -m 0644 src/matrices/*.dat "${libexec}/matrices/"
install -m 0755 art_src_MountRainier/art_illumina "${libexec}/"

sed \
  -e '1 s|^#!.*perl.*$|#!/usr/bin/env perl|' \
  -e 's|$pathdir."/src/|$pathdir."/|' \
  -e 's|$pathdir."/art_src_MountRainier/art_illumina"|$pathdir."/art_illumina"|' \
  gargammel.pl > "${libexec}/gargammel.pl"
chmod 0755 "${libexec}/gargammel.pl"
grep -q '$pathdir."/art_illumina"' "${libexec}/gargammel.pl"
# "gargammel" as in earlier versions of this package, "gargammel.pl" as in the README
ln -s ../libexec/gargammel/gargammel.pl "${PREFIX}/bin/gargammel"
ln -s ../libexec/gargammel/gargammel.pl "${PREFIX}/bin/gargammel.pl"
