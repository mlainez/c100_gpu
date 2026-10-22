# Frozen L4T stereo baseline — 2026-10-22

The exact comparison bundle is saved outside temporary directories and caches:

`/var/home/marc/.local/share/c100-gpu/baselines/l4t-sgm-20261022/`

It includes ARM64 executables, four compiled VMFB models, the exact left/right
frames and reference maps, shader/exporter/source snapshots with licenses,
captured MLIR and SPIR-V, build settings, device/library fingerprints, raw
benchmark JSON, output-validation logs and frequency samples. `SHA256SUMS`
covers every file. Its `manifest.json` records the complete argv for all four
correctness checks and four timing cases, relative to the bundle root.
A copy of the manifest and checksums is kept in `docs/reference/l4t-sgm-20261022/`.

The subsequent Nerves optimization round reaches 31.62 FPS VGA / 10.99 FPS
720p for the resident graph and 31.04 FPS for a separate complete Elixir VGA
loop. The saved L4T baseline remains unchanged. See
[`nx_iree` optimization evidence](../../nx_iree/docs/reference/stereo-nvidia-20261022/optimization-round.md)
for correctness, rejected experiments and the remaining parity gap.

## Stack used

| Component | Version or configuration |
|---|---|
| Device | OKdo C100, P3448-0002, Tegra210 GM20B |
| OS | NVIDIA L4T R32.7.6, Ubuntu18.04.6, glibc2.27 |
| Kernel | 4.9.337-tegra |
| NVIDIA 3D package | 32.7.6-20241104234540 |
| Vulkan driver / actual loader | 1.2.131 / 1.2.141 |
| IREE runtime and compiler | 3.11.0, e4a3b0405d7d23554da26403658d0e8c3c5ecf25 |
| Compiler version output | 3.11.0rc20260316, LLVM23.0.0git |
| Runtime build | Release, Vulkan enabled, no runtime source patches |
| Cross compiler | GCC13.3.0; Ubuntu18.04 ARM64 sysroot; static libstdc++/libgcc |
| GLSL compiler | glslang16.1.0, Vulkan1.1 target |
| Allocator | IREE `caching:device_local=256mib;512mib;64` |
| RAM during every timing sample | 1600MHz, normal EMC frequency scaling |
| GPU / CPU limits | 921.6MHz / 1479MHz |
| GPU / CPU governors | nvhost_podgov / schedutil; MAXN |

This is a Vulkan compute graph, with no CUDA or OpenCV execution. Elixir/Nx
was used on the host to export the graph; the timed L4T execution uses native
IREE command-line tools. Current IREE3.13 requires Vulkan1.3, which is why
the portable Vulkan1.2-compatible IREE3.11 tools are frozen for comparison.

The matcher is classic48-bit Census, three paths, D64, P1=8, P2=64,
uniqueness1.0526315789473684, f32 subpixel refinement, projected consistency
and median filtering. DP block8, selection lanes8, tiled path schedule,
shared projection and fused vertical/selection dispatch. No pyramid or ROI.
All five shader blobs per resolution match the modern Nerves graph exactly.

Fixtures are frame1 of Sintel `alley_1`, clean pass, resized directly from
1024x436 to640x480 or1280x720 with Lanczos. Raw inputs are row-major
little-endian i32 grayscale; reference disparities are f32. The720p fixture
is upscaled/aspect-changed. D64 has different relative range at each width.

## Recorded result

| D64 resident-input GPU graph | Cached serial | Async concurrency4 |
|---|---:|---:|
| 640x480 | **45.796 FPS** | 45.931 FPS |
| 1280x720 | **15.594 FPS** | 15.573 FPS |

Three repetitions, benchmark_min_time0.5s. All reference checks pass at
absolute tolerance0.0001, with zero new GPU errors. Timings exclude input
upload, output readback, camera/network capture and Elixir scheduling.
They must not be directly compared with earlier Nerves whole-loop FPS.
Serial exports require batch_size1; the async exports have a coarse-fence
ABI and use actual batch_size4/batch_concurrency4 invocations.

## Nerves comparison

The user returned to Nerves from SD. Boot
`a1415b28-a332-4bfe-9652-7069b9fc2819` runs kernel6.18.57, Mesa26.1.8/NVK,
validated slotB, EMC1600MHz and normal governors. The complete comparison
adds zero errors to its fresh GPU log. All12 staged artifact hashes match.

The frozen unpatched3.11 tool fails numeric output on NVK and stops before
timing. Backporting only the two existing generic mapped-buffer flush and
source-invalidation fixes into an isolated3.11 build restores all four
output checks. Models, inputs, allocator and timed graph are unchanged.
The L4T bundle and its runtime remain untouched. Record this compatibility
delta whenever citing the comparison; these are not identical runtime binaries.

| D64 resident-input graph | Nerves/NVK | L4T/NVIDIA |
|---|---:|---:|
| VGA, serial | 30.686 FPS | 45.796 FPS |
| VGA, async4 | 30.746 FPS | 45.931 FPS |
| 720p, serial | 10.689 FPS | 15.594 FPS |
| 720p, async4 | 10.627 FPS | 15.573 FPS |

All timing EMC samples are1600MHz and GPU reaches921.6MHz; CPU actual
frequencies vary under schedutil. Four timing probes pass after all four
numeric checks. The separate durable Nerves bundle is
`~/.local/share/c100-gpu/baselines/nerves-sgm-20261022/`, including patches,
build settings, raw results, profiles and a checksum manifest.

A separate3.13 VGA profile spends81.3% of active GPU time in aggregation and
selection. The portable report below records the profile's distinct runtime,
allocator and cold-start caveats. The remaining measured graph gap is about
1.5x; matching NVIDIA alone would still leave720p below30FPS. Preserve these
frozen models as controls while optimizing, and measure transfer/readback and
Elixir/video overhead separately. No board default runtime or governor was
changed for the comparison. Short clean probes do not establish long-run
driver stability or camera throughput.

The C100 memory-training fix, preserved SD-first boot path and rollback are
documented in [l4t-emc.md](l4t-emc.md). The broader result is recorded in
sibling `nx_iree/docs/reference/stereo-nvidia-20261022/README.md`.
