#!/bin/bash
# Upstream test suite on the installed programs: it expects the layout of the
# source tree, so give it one made of links to the installed files.
set -eu

G="${PWD}/gargammel"
mkdir -p "${G}/src" "${G}/art_src_MountRainier"
for b in fragSim deamSim adptSim fasta2fastas damage_patterns2prof mapDamage2prof; do
    ln -sf "${PREFIX}/bin/${b}" "${G}/src/${b}"
done
ln -sf "${PREFIX}/libexec/gargammel/art_illumina" "${G}/art_src_MountRainier/art_illumina"
ln -sf "${PREFIX}/libexec/gargammel/matrices" "${G}/src/matrices"
ln -sf "${PREFIX}/bin/gargammel" "${G}/gargammel.pl"
LC_ALL=C bash "${G}/tests/run_tests.sh"  # one check depends on the sort order of the locale
