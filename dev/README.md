# Jetson GPU development scripts

These historical tools were moved from `nx_iree` into the dedicated C100
library. They are preserved for reproducing old experiments. Several pin
clocks, replace staged board files, or reference old scratch directories;
use `../scripts/stereo_board_run.exs` for the current normal-devfreq tests.

Scripts used to tune Nx matmul performance on the Jetson Nano (GM20B) through
IREE's Vulkan backend and NVK. They take their scratch directory from
`C100_DEV_TMP` and the Nerves system's Buildroot artifact directory (the
`.nerves/artifacts/nerves_system_okdo_c100-*` directory holding the Mesa
source and toolchain) from `NERVES_SYSTEM_ARTIFACT`. `nakdis.py` finds
nvdisasm through `NVDISASM`, and `nvk-host-icd.json` needs `MESA_HOST_BUILD`
replaced by the host Mesa build directory.

## Compiling for the GM20B without the board

`mesa-host-build.sh` builds the patched NVK (Buildroot's `mesa3d-26.1.8`
source with the system's NAK patches) natively on the host, together with the
nouveau drm-shim. With `NOUVEAU_CHIPSET=12b`, NVK then creates pipelines for an
emulated GM20B and NAK compiles exactly as on the board:

- `shim-nak.sh <modules.bin> "<op> <n>" <out.log>` loads AOT modules
  (`bench/shim_load.exs`) on the shim with `NAK_DEBUG=print`.
- `nakdis.py <log> <n>` disassembles the n-th shader with nvdisasm (SM53).
- `sass-region.py` summarises a loop: opcode mix and where loads, stores and
  barriers sit. `spirv-order.py` does the same for IREE's `.spirv.mlir` dumps.

## Matmul configurations

`bench/tuning/matmul_spec.py` writes a transform-dialect library that sets the
SPIR-V matmul tiling, workgroup size and pipeline depth. It is passed with
`--iree-codegen-transform-dialect-library=` (`--iree-codegen-tuning-spec-path`
is ignored by the SPIR-V pipeline). `sweep-configs.sh matmul-configs.txt`
compiles each configuration and reports NAK's GPR count and whether global
loads precede the FMAs.

## Board

- `nak-push.sh` rebuilds Buildroot's Mesa with edited NAK sources and pushes the
  driver to `/root/nvkexp` (select it with `VK_DRIVER_FILES`).
- `stage-modules.sh` and `board-bench.sh` stage AOT modules and run
  `bench/jetson/run.exs` on the board through `bench/jetson/board_run.exs`.
- `build-nxiree-*-aarch64.sh` cross-build the runtime and NIF by hand until the
  Makefile supports Nerves.

Keep board runs short and the GPU clock low (`NXIREE_PIN_HZ`) on a weak supply:
load steps on a high-resistance supply path trip the board's undervoltage
protection, and a GPU left in a bad state needs a full power-off to recover.

## NAK patch

`../patches/mesa/0013-*.patch` lets NAK's
schedulers reorder memory instructions that cannot conflict. It applies on top
of the system's patches 0001-0012 and is not in the firmware yet.
