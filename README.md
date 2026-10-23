# C100 GPU support

This Elixir library contains GPU settings and board tooling specific to the
OKdo C100's Tegra210 GM20B. Generic Nx/IREE compilation, Vulkan execution,
memory management and stereo path kernels remain in `nx_iree`.

[L4T EMC boot configuration](docs/l4t-emc.md) preserves CBoot's memory
training and the SD-first Nerves boot path. The verified L4T configuration
restores1600MHz RAM and raises the unchanged D64 graph to45.8FPS at640x480
and15.6FPS at1280x720, excluding camera input and output readback.

The [frozen L4T stereo baseline](docs/l4t-sgm-baseline.md) saves the exact
stack, binaries, models, fixture data and run arguments. The subsequent
Nerves comparison reaches30.69FPS VGA and10.69FPS720p with the same graph
and two required generic host-cache backports in IREE3.11. Both bundles are
retained outside the cache; the report records the runtime compatibility
delta, clean GPU logs and actual verification of Nerves booting from SD.

Use the existing Maxwell matmul tuning with:

```elixir
NxIREE.export(&Nx.dot/2, templates,
  iree_compiler_flags: ["--iree-hal-target-backends=vulkan-spirv"],
  iree_tuning: {C100GPU.Tuning, :maxwell_matmul}
)
```

`C100GPU.Target.compiler_flags/0` supplies the C100 NVK capability list.
The tuning spec is unchanged: 64x64x8 workgroup tiles, 16x8 threads and a
single buffering stage. Its earlier measured performance is recorded in
`../nx_iree/docs/jetson-results.md`; extracting it does not establish a new
performance result.

[Normal-devfreq matmul checks](docs/normal-dvfs.md) record the later
continuous and idle-to-load measurements with the accepted firmware.

## YOLOv5s through IREE on the GPU

YOLOv5s (640x640) compiled by IREE for NVK runs at 458 ms per frame on the
C100 in fp16 and 589 ms in fp32, against 453 ms for ncnn on the four A57
cores, 1183 ms for ncnn's own Vulkan path on NVK and 931 ms for OpenCV DNN.
The fp16 detections match OpenCV DNN's fp32 result (54 of 54 candidates,
same classes); the fp32 output matches within 0.05.

The recipe is vendor-neutral and lives in `../nx_iree/bench/yolo`. This
library adds only the GM20B tuning:

```sh
# fp16 export, f16 accumulators (fastest)
F16=1 ../nx_iree/bench/yolo/compile.sh yolov5s-fp16.mlir yolov5s.vmfb pascal priv/tuning/yolov5s_maxwell_f16.mlir
# fp32
../nx_iree/bench/yolo/compile.sh yolov5s.mlir yolov5s.vmfb turing priv/tuning/yolov5s_maxwell.mlir
```

The GM20B runs packed fp16 (HFMA2) at twice the f32 rate, through the
system's NAK and NVK patches 0008 and 0009. The fp16 export alone does not
use it: the ONNX importer accumulates f16 convolutions in f32, so NAK emits
f32 FMAs plus conversions, and the frame gets slower (886 ms).
`F16=1` (`--iree-input-demote-f32-to-f16`) keeps accumulators in f16, as
TensorRT's fp16 mode does; the matmuls then compile to HFMA2. With the
compiler's default f16 tiles that gives 706 ms, and the spec's 8x8 f16
blocks per thread on small workgroups give 458 ms. The `turing` preset
cannot compile the f16 graph (its cooperative-matrix path rejects the stem).

The fp32 spec gives the stem and the 20x20-map matmuls an 8x4 output block
per thread. Without it the padded fp32 model runs at 738 ms; unpadded and
untuned with the `rdna1` preset it took 1.9 s. In fp32, matmuls take
346 ms of the remaining 532 ms of GPU time, im2col 81 ms, layout transposes
46 ms and the detect head's odd-width copies 38 ms.

Published Jetson Nano results on NVIDIA's own stack are faster. ncnn's
Vulkan path on NVIDIA's L4T driver runs YOLOv5s at about 5 FPS on a
640x480 letterboxed input (Qengineering's YoloV5-ncnn-Jetson-Nano), where
the same ncnn shaders take 1183 ms at 640x640 on NVK, about 4.5x slower
after scaling for the input area. TensorRT fp16 is reported at roughly
60-100 ms at 640. The remaining gap is therefore mainly NAK's Maxwell code
generation and NVK, not the model or the IREE graph.

The current development dependency uses the sibling `../nx_iree` checkout.
Run `mix deps.get` and `mix test` for ordinary tests. The Vulkan matmul
correctness check is opt-in:

```sh
NXIREE_DEVICE_MATCH='<device URI substring>' mix test --include hardware
```

This test compiles on the host and requires a Vulkan device. Board deployment
uses host-exported modules because the firmware contains only the IREE runtime.

`scripts/stereo_board_run.exs` is evaluated in the C100's main Nerves node.
It runs the generic stereo benchmark in a separate BEAM, bounds execution to
120 seconds, and checks the benchmark result and Nouveau error log. It retains
normal devfreq settings. Its default paths are `/root/nxiree/stereo-run.exs`
and `/root/nxiree/stereo.bin`; `STEREO_SCRIPT`, `STEREO_BUNDLE` and
`STEREO_RUNTIME_ROOT` override the script, module bundle and staged runtime
root. It performs no firmware installation or reboot.

The system's dedicated `package/c100-gpu` Buildroot package supplies the
boot-time `c100-limits` script. Its CPU/GPU limits and first-channel sequence
are independent of the Elixir tuning provider.

The historical `bench/jetson/` exporters and runners are preserved for prior
results. From `bench/`, run `mix deps.get` before invoking them with `mix run`.
`TUNING=maxwell_matmul` selects this library's provider in the DistilBERT exporter.
The old `bench/jetson/board_run.exs` pins clocks and pauses other processes;
do not use it against the current normal-DVFS baseline. Use the current script
for stereo tests.

The complete portable stereo-video benchmark is in
`../nx_iree/bench/stereo/video`. On C100, export with
`VIDEO_STORAGE=packed16 VIDEO_FUSE_SELECT=1 VIDEO_LINES_PER_GROUP=4`.
The same kernels use one scan line/group on the tested host AMD GPU.
The C100 runs about 10.3 FPS for 320×136 / D=64 / eight directions per
camera, including transfers, with normal devfreq and unchanged disparity.
See `../nx_iree/docs/reference/stereo-efficiency-20261022/README.md` for
measurements, correctness checks and remaining limits. The matcher expects
rectified grayscale images and does not include video decoding.

The production stereo target is faster GPU processing than optimized OpenCV
CPU processing at comparable quality, including transfers and synchronization.
The latest prototype has a conditional throughput lead; production acceptance
and standard Evision GPU SGBM integration remain open. The separate Evision
CPU benchmark is an accuracy/performance reference, not the delivered GPU
implementation. Prefer upstream GPU libraries with thin Elixir integration;
generic execution and algorithms remain portable, while this library owns
only C100 policy and tooling. See
`../nx_iree/docs/reference/stereo-library-survey-20261022/README.md`.

The generic libSGM Vulkan port experiment in `../nx_iree/bench/stereo/census`
now reaches 28–29 FPS with eight directions on two 50-frame Sintel sequences,
including transfers and synchronization. Its measured accuracy is close to
CPU 3WAY, which still reaches 94–101 FPS. A three-direction GPU tradeoff
reaches 36–39 FPS with somewhat worse accuracy on the first scene. This is
not an accepted production package. See
`../nx_iree/docs/reference/stereo-census-reuse-20261022/README.md` for the
specific export flags, fixtures, timings and limitations. The existing
guarded child harness runs it with `CENSUS_STEREO_PASS`; no C100 policy or
native runtime change is required.

The subsequent generic composed IREE pipeline reaches 49–53 FPS in bounded
diagnostics. The unchanged selector preserves all 100 earlier outputs; CPU
3WAY remains faster. The shared OpenCV-style projection follow-up reaches
61–69 FPS, with 9–20% gains in paired runs and all 100 predictions unchanged.
Generic IREE mapped initialization reduces uploads by about 1–1.4 ms/frame,
without a consistent further FPS gain. Its target runtime is isolated;
the board's default NIF/runtime remains unchanged. See
`../nx_iree/docs/reference/stereo-shared-20261022/README.md` and
`../nx_iree/docs/reference/stereo-graph-20261022/README.md`. A rapid native
profiling run exposed unresolved `nv50cal_space: -110` errors. The guarded
harness now requires `board_gpu_log.exs` beside it, rejects any existing GPU
error by default, and stops its child on a newly detected error. Explicit
`C100_GPU_DIAGNOSTIC=1` retains the initial error baseline and reports only
`BOARD_DIAGNOSTIC_PASS`; this cannot establish clean driver acceptance.

The standard Evision keyword API already accepts and returns UMat on the
board. Existing OpenCV OpenCL kernels over clvk are the preferred integration
route to evaluate before expanding custom vision code. SGBM remains a
missing GPU implementation, and the current board has no OpenCL device.
The host prototype now executes standard Evision color conversion, resize,
median filtering and remap through clvk/Vulkan on RX 7800 XT, with correct
output and actual kernel dispatch logs. Use clvk's in-process compiler:
the external-compiler build fails its child wait inside the tested BEAM.
This is host compatibility evidence; no ARM64 clvk package or GPU SGBM
backend is installed, and the small host chain is slower than CPU.
See `../nx_iree/docs/reference/evision-acceleration-20261022/README.md`.

Set `STEREO_SCRIPT` to the video runner and provide `VIDEO_DATA` and
`VIDEO_OUTPUT` for the child process. `STEREO_SUCCESS_MARKER` optionally
changes the harness's required result marker; it defaults to
`STEREO_PATH_PASS`. This lets the same guarded harness run the generic
Vulkan buffer-stream benchmark (`VULKAN_STREAM_PASS`) without clock changes.

For a native tool, `C100_GPU_COMMAND_FILE` optionally selects a trusted
Erlang external-term file containing `{absolute_executable, argv}` instead
of a child BEAM. Create it with `:erlang.term_to_binary/1`; argv is a list
of strings. The same guard then owns and kills the actual native PID.
`C100_GPU_TIMEOUT_MS` sets its deadline, from 1 to 120000 ms (default
120000). `STEREO_SUCCESS_MARKER`, exit status and live GPU-error checks
still apply. `CHILD_PID` identifies the monitored process. Leaving the
command-file option unset preserves the existing Elixir execution path.

Explicit IREE profiling with
`--device_profiling_mode=dispatch-events,device-queue-events,queue-events`
captures real Vulkan dispatch timestamps; lightweight `--dispatch_statistics`
does not enable them. The bounded native capture and timeout/Elixir-path QA
are recorded in `../nx_iree/docs/reference/stereo-saturation-20261022/README.md`.

`scripts/compare_stereo_at_max.exs` is an explicit diagnostic comparison.
It temporarily raises the minimum to the accepted 921.6 MHz cap for both
compiler versions, then restores the original minimum in `after`. It
retains the normal governor and is not run by the application or at boot.

`scripts/cpu_performance_probe.exs` is a separate bounded diagnostic. It wraps
the existing guarded child, temporarily selects the CPU `performance`
governor within the existing maximum (which must not exceed 1479000 kHz),
and restores the saved governor in `after`, including guard timeout/failure.
`C100_GPU_GUARD` optionally selects another path to `stereo_board_run.exs`.
It does not change the GPU governor, GPU/EMC limits or any boot policy.

The latest generic libSGM fusion and existing IREE mappable-readback path
reach 121–140 whole-loop FPS at 320×136/D64 in this CPU diagnostic, versus
85–89 for four-thread CPU 3WAY with the same CPU policy. Normal CPU schedutil
gives about 101–104 GPU FPS. All 100 downloaded results are unchanged.
This is short-run performance evidence with 23 historical driver errors,
not clean driver acceptance. The corrected runtime is isolated under
`/root/nxiree/sgm-final-mappable-runtime`; the default board libraries are
preserved. See `../nx_iree/docs/reference/stereo-fused-20261022/README.md`
for the conditions, rejected experiments and native fixes.

`scripts/cpu_load_probe.exs` defines `C100GPU.CpuLoadProbe.run(workers, fun)`
for a controlled coexistence test. It uses OTP `Task.Supervisor` and existing
`:crypto`/OpenSSL SHA256 with zero to two workers in the caller's BEAM;
`fun` invokes the existing guarded benchmark child. All workers stop when
the callback returns or fails. The helper changes no governors or limits.
Its CPU accounting covers all caller-BEAM threads and the whole callback,
including startup/output validation, not only the child's measurement window.

In 1,000-pair tests with normal CPU/GPU governors, two background workers
use about two CPU cores while GPU stereo sustains 151–152 FPS at 320×136/D64.
CPU 3WAY with the same work reaches 51–52 FPS. All repeated outputs agree;
this demonstrates useful CPU offload with a controlled workload, not a
particular application or camera pipeline. See
`../nx_iree/docs/reference/stereo-concurrency-20261022/README.md`.

The portable `NxIREE.Serving` adapter now runs the same export through existing
Nx.Serving streams without a compiler on C100. With two CPU workers and normal
governors, one context processes 1,000 scheduled 320×136/D64 pairs in about
10.001 seconds, using 0.64–0.67 matcher CPU cores. Completion latency p95 is
21–24 ms; scheduled latency can reach 51–56 ms. An idle-CPU short control only
reaches 79 FPS, so arbitrary-workload 100-Hz pacing remains open. All 200
downloaded C100 maps are unchanged, with zero new driver errors. The isolated
runtime is `/root/nxiree/sgm-serving-runtime`; see
`../nx_iree/docs/reference/stereo-serving-20261022/README.md` for conditions,
tests and reproduction. This remains prepared replay, with no cameras attached.

`dev/` and `patches/mesa/0013-*` preserve the earlier C100/NAK experiments.
Patch 0013 is not installed in the accepted firmware and did not improve
the tuned matmul measurement. Review the historical tools before reuse;
they still contain old scratch paths and board-changing commands.

The [native VGA stereo follow-up](../nx_iree/docs/reference/stereo-vga30-20261022/README.md)
reaches 31.3 prepared-pair GPU FPS at 640×480 per eye/D64 and sustains a paced
30 Hz network replay with four ordinary Nx.Serving contexts. Normal CPU
schedutil/GPU simple_ondemand and all existing limits remain unchanged;
no artificial CPU load or CPU frequency floor is needed for the four-context
idle replay. Processing latency is about124 ms median. Two-context idle
replay falls behind, so do not infer it from loaded-CPU timings.
Every replay checks input/output hashes and adds zero GPU errors to the
historical23-error baseline. No firmware/default-library install or reboot
occurs. Camera capture, rectification, clean driver-load acceptance and
standard Evision GPU SGBM integration remain open.
