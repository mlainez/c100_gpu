#!/usr/bin/env bash
# AOT-compile the Jetson test modules for each given IREE Vulkan target into
# the board bundle (one jetson-modules-<target>.bin each).
set -e
B=${NX_IREE_BENCH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../nx_iree/bench" && pwd)}
OUT=${C100_DEV_TMP:?set C100_DEV_TMP to a scratch directory}/nxiree-board
rm -f $OUT/jetson-modules*.bin
cd $B
for t in "$@"; do
  NXIREE_VULKAN_TARGET=$t AOT_OUT=$OUT/jetson-modules-$t.bin mix run aot.exs 2>&1 | tail -1
done
