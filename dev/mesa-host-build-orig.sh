#!/usr/bin/env bash
# Second host NVK build with the NAK the firmware ships (patches 0001-0012
# only), in its own source and build trees, so the board's code can be
# reproduced on the drm-shim next to the patched build.
set -e
A=${NERVES_SYSTEM_ARTIFACT:?set NERVES_SYSTEM_ARTIFACT to the Buildroot artifact directory of the C100 system}
T=${C100_DEV_TMP:?set C100_DEV_TMP to a scratch directory}
SRC=$T/mesa-host-src-orig
B=$T/mesa-host-build-orig
TOOLS=$T/mesa-host-tools
export PATH=$TOOLS:$PATH
export LIBCLANG_PATH=$A/host/lib
export BINDGEN_EXTRA_CLANG_ARGS="-isystem $A/host/lib/clang/22/include"
export LD_LIBRARY_PATH=$A/host/lib
if [ ! -d $SRC ]; then
  mkdir -p $SRC
  rsync -a --exclude 'build*/' $T/mesa-host-src/ $SRC/
  cp $T/nak-orig/*.rs $SRC/src/nouveau/compiler/nak/
fi
if [ ! -d $B ]; then
  meson setup $B $SRC \
    -Dbuildtype=release -Dvulkan-drivers=nouveau -Dgallium-drivers= -Dplatforms= \
    -Dglx=disabled -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dopengl=false \
    -Dtools=drm-shim -Dmesa-clc=system -Dprecomp-compiler=system -Dllvm=disabled \
    -Dvulkan-layers= -Dbuild-tests=false
fi
ninja -C $B
sed "s|mesa-host-build/|mesa-host-build-orig/|" $T/mesa-host-build/nvk-host-icd.json > $B/nvk-host-icd.json
