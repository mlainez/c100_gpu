#!/usr/bin/env bash
# Cross-compile libnx_iree.so (the NIF) for the Jetson and lay out a priv dir.
# Usage: build-nxiree-nif-aarch64.sh <nx_iree dir> <out priv dir>
set -e
NX=$1
OUT=$2
TC=${NERVES_TOOLCHAIN:?set NERVES_TOOLCHAIN to the Nerves aarch64 toolchain directory}
ART=${NERVES_SYSTEM_ARTIFACT:?set NERVES_SYSTEM_ARTIFACT to the Buildroot artifact directory of the C100 system}
ERTS=$(ls -d $ART/staging/usr/lib/erlang/erts-*/include)
INST=$NX/iree-runtime/aarch64/install
mkdir -p "$OUT/iree-runtime"
cp -a $INST/libnx_iree_runtime.so "$OUT/iree-runtime/"
$TC/bin/aarch64-nerves-linux-gnu-g++ -fPIC -O3 -std=c++17 -w \
  -I$ERTS -I$INST/include \
  -shared -o "$OUT/libnx_iree.so" $NX/c_src/nx_iree.cc \
  -L$INST -lnx_iree_runtime -Wl,-rpath,'$ORIGIN/iree-runtime'
$TC/bin/aarch64-nerves-linux-gnu-strip "$OUT/libnx_iree.so" "$OUT/iree-runtime/libnx_iree_runtime.so"
cp $NX/priv/VERSION "$OUT/"
ls -la "$OUT" "$OUT/iree-runtime"
