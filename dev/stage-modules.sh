#!/usr/bin/env bash
# Put the given sweep module files (by config name, or "default" for the
# rdna3 preset) into the board bundle.
set -e
T=${C100_DEV_TMP:?set C100_DEV_TMP to a scratch directory}
rm -f $T/nxiree-board/jetson-modules*.bin
for n in "$@"; do
  if [ "$n" = default ]; then
    (cd "${NX_IREE_BENCH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../nx_iree/bench" && pwd)}" && NXIREE_VULKAN_TARGET=rdna3 AOT_OUT=$T/nxiree-board/jetson-modules-default.bin mix run aot.exs > /dev/null 2>&1)
  else
    cp $T/sweep/$n.bin $T/nxiree-board/jetson-modules-$n.bin
  fi
done
ls $T/nxiree-board/
