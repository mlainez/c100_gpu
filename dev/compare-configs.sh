#!/usr/bin/env bash
# Dump the 1024 matmul for each target and print IREE's chosen config.
S=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
D=${C100_DEV_TMP:?set C100_DEV_TMP to a scratch directory}/irdump
for t in "$@"; do
  [ -d $D/$t-1024 ] || bash $S/iree-dump.sh 1024 $t > /dev/null 2>&1
  cfg=$(grep -ohE 'tile_sizes = [^>]*>|workgroup_size = \[[^]]*\]|spirv_pipeline<[A-Za-z]+>|subgroup_size = [0-9]+|pipeline_depth = [0-9]+' $D/$t-1024/files/configured_*.mlir | sort -u | tr '\n' ' ')
  echo "$t: $cfg"
done
