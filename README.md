# C100 GPU support

GPU settings and board tooling for the OKdo C100's Tegra210 GM20B (Mesa NVK).
Everything generic lives elsewhere: Nx compilation and Vulkan execution in
[`nx_iree`](../nx_iree), stereo matching in [`nx_stereo`](../nx_stereo).
This library holds only what is specific to this GPU and board.

## Target flags and tuning

`C100GPU.Target.compiler_flags/0` is the NVK capability list for
`--iree-vulkan-target-features`. `C100GPU.Tuning.compiler_flags/1` returns
IREE transform-dialect tuning specs measured on the GM20B, as ordinary
`iree-compile` flags:

```elixir
flags =
  ["--iree-hal-target-backends=vulkan-spirv" | C100GPU.Target.compiler_flags()] ++
    C100GPU.Tuning.compiler_flags(:maxwell_matmul)

Nx.Defn.jit(&Nx.dot/2, compiler: NxIREE.Compiler, iree_compiler_flags: flags)
```

`:maxwell_matmul` uses 64x64x8 tiles, 16x8 threads and a single buffering
stage; its measurements are in `../nx_iree/docs/jetson-results.md` and
[normal-devfreq matmul checks](docs/normal-dvfs.md). The YOLOv5s specs are
described below.

## YOLOv5s through IREE on the GPU

YOLOv5s compiled by IREE for NVK runs at 199 ms per frame (5.0 FPS) on a
640x512 input, the letterboxed size of a 4:3 frame, and 242 ms at 640x640.
Its detections match onnxruntime's fp32 result. For comparison, ncnn's
Vulkan path on NVIDIA's own L4T driver reaches about 5 FPS on 640x480
inputs (Qengineering's YoloV5-ncnn-Jetson-Nano), ncnn on the four A57 cores
takes 453 ms and ncnn's Vulkan path on NVK 1183 ms at 640x640.

The recipe is vendor-neutral and lives in `../nx_iree/bench/yolo`. This
library adds only the GM20B spec:

```sh
../nx_iree/bench/yolo/prepare.sh yolov5s.onnx yolov5s-512x640 512 640   # fp16 export
F16=1 WINOGRAD=1 ../nx_iree/bench/yolo/compile.sh yolov5s-512x640.mlir yolov5s.vmfb pascal priv/tuning/yolov5s_maxwell_f16.mlir
```

The GM20B runs packed fp16 (HFMA2) at twice the f32 rate through the
system's NAK and NVK patches 0008 and 0009, but only with f16 accumulators
(`F16=1`); the importer's default f32 accumulators made fp16 slower than
fp32. From the full export in fp32 at 640x640 (589 ms with
`priv/tuning/yolov5s_maxwell.mlir`) the steps were: fp16 with f16
accumulators 458 ms, Detect layer decoded on the host 427 ms, a spec with
8x4 blocks per thread and no register spills 331 ms, Winograd 300 ms,
640x512 254 ms, concatenated 1x1 convolutions split 225 ms, Focus stem and
the pooling rule 199 ms.

In the last profile the GPU is busy 186 ms per frame: matmuls 135 ms at
63 GFLOPS on average (out of about 440 GFLOPS fp16 peak), Winograd
transforms and im2col copies 29 ms, other copies 16 ms. The small-K 1x1
convolutions (20-33 GFLOPS) and Winograd's batched matmuls on the small
maps are the least efficient; tiling them differently measured slower.

## Stereo

`NxStereo.sgm/3` runs on the C100 through `NxIREE.Compiler` as six compute
shaders. At 640x480 with 64 disparities it takes 31 ms per pair with the
images on the device (32 FPS) and 51 ms with upload and readback, matching
the EXLA reference on every pixel. The work that produced the shaders, the
NVIDIA L4T comparison and every earlier measurement are recorded in
`../nx_iree/docs/stereo-path.md` and `../nx_iree/docs/reference/stereo-*`.
[L4T EMC boot configuration](docs/l4t-emc.md) and the
[frozen L4T stereo baseline](docs/l4t-sgm-baseline.md) document the NVIDIA
reference setup.

## Board scripts

`scripts/stereo_board_run.exs` is the guarded runner for GPU work on the
board, evaluated in the C100's main Nerves node. It runs a child BEAM (or,
with `C100_GPU_COMMAND_FILE`, a native `{absolute_executable, argv}` written
with `:erlang.term_to_binary/1`), bounds it to `C100_GPU_TIMEOUT_MS`
(1 to 120000 ms, default 120000), and fails on a non-zero exit, a missing
`STEREO_SUCCESS_MARKER` (default `STEREO_PATH_PASS`) or any new Nouveau
error in the kernel log. `STEREO_SCRIPT` selects the child script and
`STEREO_RUNTIME_ROOT` a staged runtime (`lib/<app>/{ebin,priv}`) the script
can add to its code path. `C100_GPU_DIAGNOSTIC=1` keeps an existing error
baseline and reports `BOARD_DIAGNOSTIC_PASS` instead. It changes no clocks,
limits or firmware.

  * `scripts/compare_stereo_at_max.exs` temporarily raises the GPU minimum to
    the accepted 921.6 MHz cap for a comparison and restores it.
  * `scripts/cpu_performance_probe.exs` runs the guarded child with the CPU
    `performance` governor within the existing maximum and restores it.
  * `scripts/cpu_load_probe.exs` (`C100GPU.CpuLoadProbe.run(workers, fun)`)
    runs zero to two SHA-256 workers in the caller's BEAM while `fun` runs,
    for coexistence measurements.

IREE device profiling with
`--device_profiling_mode=dispatch-events,device-queue-events,queue-events`
records Vulkan dispatch timestamps; `--dispatch_statistics` does not.

The system's `package/c100-gpu` Buildroot package supplies the boot-time
`c100-limits` script, independently of this library.

## Development

`mix test` runs the ordinary tests. The Vulkan matmul check is opt-in and
needs a Vulkan device:

```sh
NXIREE_DEVICE_MATCH='<device URI substring>' mix test --include hardware
```

The firmware contains only the IREE runtime, so the board runs modules
compiled on the host: a module cache (`:iree_module_cache`) for ordinary Nx
code, or `NxIREE.export/3`. `bench/jetson/` holds the matmul and DistilBERT
exporters and runners behind the recorded Jetson results (`TUNING=maxwell_matmul`
selects the matmul spec); its `board_run.exs` pins clocks and pauses other
processes, so do not use it against the normal-DVFS baseline. `dev/` and
`patches/mesa/0013-*` preserve the earlier NAK and SASS analysis tools; patch
0013 is not in the firmware and did not improve the tuned matmul. The tools
still contain scratch paths and board-changing commands; review them before
reuse.
