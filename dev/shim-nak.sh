#!/usr/bin/env bash
# Compile AOT modules with the host NVK on the GM20B drm-shim and dump NAK's
# output. Usage: shim-nak.sh <modules.bin> "<op> <n>" <out.log> [extra env K=V...]
set -e
T=${C100_DEV_TMP:?set C100_DEV_TMP to a scratch directory}
B=$T/mesa-host-build
MODS=$1
KEY=$2
OUT=$3
shift 3
cd "${NX_IREE_BENCH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../nx_iree/bench" && pwd)}"
env AOT_MODULES="$MODS" AOT_KEYS="$KEY" \
  VK_DRIVER_FILES=$B/nvk-host-icd.json \
  LD_PRELOAD=$B/src/nouveau/drm-shim/libnouveau_noop_drm_shim.so \
  NOUVEAU_CHIPSET=12b NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1 NAK_DEBUG=print MESA_SHADER_CACHE_DISABLE=true "$@" \
  mix run shim_load.exs > "$OUT" 2>&1 || true
grep -E "^devices|^=== |Encoded shader|error|Error" "$OUT" | head -20
