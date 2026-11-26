#!/bin/bash
set -euxo pipefail

install -d "${PREFIX}/bin"
install -m 0755 vgan-linux-x86_64 "${PREFIX}/bin/vgan"

# vgan looks for its data relative to the executable, in ../share/vgan/.
# The databases are not included (separate downloads, see the README);
# damageProfiles/none.prof is required by euka, soibean and TrailMix.
src=vgan-src/share/vgan
dst="${PREFIX}/share/vgan"
install -d "${dst}/damageProfiles" "${dst}/plottingScripts" "${dst}/hc_scripts" "${dst}/soibean_dir"
install -m 0644 "${src}"/damageProfiles/*.prof "${dst}/damageProfiles/"
install -m 0644 "${src}"/plottingScripts/*.yml "${src}"/plottingScripts/*.R "${dst}/plottingScripts/"
install -m 0755 "${src}"/plottingScripts/*.py "${src}"/plottingScripts/*.sh "${dst}/plottingScripts/"
install -m 0755 "${src}/hc_scripts/vcf2fasta.py" "${dst}/hc_scripts/"
install -m 0755 "${src}/soibean_dir/make_graph_files.sh" "${dst}/soibean_dir/"
# soibean resolves this directory at startup, before it reads --soibean_dir or
# --tree_dir, and exits if it is missing (conda drops empty directories).
install -d "${dst}/soibean_dir/tree_dir"
echo "placeholder: soibean needs this directory to exist" > "${dst}/soibean_dir/tree_dir/.keep"
