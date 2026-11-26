#!/bin/bash
cat >> "${PREFIX}/.messages.txt" <<MSG
vgan: the database files are not included in this package. Download the ones
you need (euka_dir, hcfiles, soibean_dir, tmfiles) as described in
https://github.com/grenaud/vgan#database-files and unpack them in
${PREFIX}/share/vgan/ (or give their location with --euka_dir, --hc-files,
--soibean_dir or --tm-files). For a soibean database kept elsewhere, also pass
--tree_dir <your soibean_dir>/tree_dir. The database folders and their *.dist
files must be writable. TrailMix also needs the SAFARI mapper in
${PREFIX}/dep/safari_vg/bin/vg (https://github.com/grenaud/SAFARI/releases).
MSG
