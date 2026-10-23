# Matmul with normal GPU power management

On 2026-10-22, the accepted firmware
`1ffb5cb3-94bd-54a7-f1e2-ec9661ce6746` ran 1024×1024 f32 matmul with
`simple_ondemand`, minimum 76.8 MHz and maximum 921.6 MHz. No clocks,
voltages, firmware or boot state were changed for these measurements.

The original IREE v3.13.0 compiler exported default and
`{C100GPU.Tuning, :maxwell_matmul}` modules. Both passed exact full-output
checks with two input values on the host RADV GPU and the C100. Both had
empty input write sets and preserved caller inputs. The board used the
isolated runtime containing the generic TLSF slab-reuse fix.

| C100 measurement | Default generation | C100 tuning |
| --- | --- | --- |
| Ten continuous calls, invocation plus readback | 69.9–91.6 ms | 29.7–35.9 ms |
| GPU frequency before and after each continuous call | 921.6 MHz | 921.6 MHz |

With 100 ms pauses, calls after warmup started at 76.8 MHz and ended at
921.6 MHz. Most tuned calls then took about 95–118 ms. These pauses measure
idle-to-load behavior as well as computation; continuous workload and burst
latency should be reported separately. This does not justify restoring a
fixed governor or changing voltage calibration.

These timings include a 4 MiB result readback and are not directly comparable
to the earlier 98.8 GFLOPS kernel measurement. The host ran a compiler build
concurrently, so its captured timings are correctness evidence only.

[Captured logs and test scripts](reference/normal-dvfs-20261022/) retain the
exact local checkout and staging paths used for this check. The export
script was run with `MIX_ENV=test mix run --no-compile` from `nx_iree`, whose
test compiler link selected the original wheel. The board's bounded child
harness checked `MATMUL_PASS` for these runs. All runs exited successfully
and the board logged no Nouveau error.

## Stereo recurrence comparison

The generic compiler repair removes a full-volume copy at every scan step.
Under normal devfreq, both old and new modules show variable clocks and
latency. The captured frequency probes establish that normal workload
execution does not hold the GPU at its maximum frequency.

`scripts/compare_stereo_at_max.exs` performs an explicit controlled test,
requiring the accepted 921.6 MHz maximum and `simple_ondemand`. It raises
the minimum to that maximum only for the bounded child tests, stops on the
first failure, and restores the original minimum and environment in
`after`. It does not alter the voltage curve or the governor.

For the 160×120×64 recurrence, ten measured calls took 198–223 ms with the
original compiler and 107–122 ms with the patched compiler. Both produced
exact results, preserved inputs and logged no GPU error. The script then
reported `RESTORED_GPU_MIN=76800000` and
`RESTORED_GOVERNOR=simple_ondemand`; a later read confirmed 76.8 MHz idle.
This script is a diagnostic comparison, not the production power policy.

Evidence: `stereo-frequency-{baseline,affinity}-board.log` and
`stereo-controlled-max-board.log` in the same reference directory.

## Whole-line kernel comparison

The portable stereo kernels, then in `nx_iree/bench/stereo` and now the
`nx_stereo` library, were imported through `NxIREE.Vulkan.export/4`. At the same accepted clock,
the final subgroup version took 11.004–14.838 ms including readback for
160×120×64, with a 3.402 ms median invocation and 11.138 ms median total.
The previous Nx path measured a 109.407 ms total median in that comparison.
All variants passed exact results and input-preservation checks, with no
GPU errors. Normal devfreq remains variable and is unchanged.

`compare_stereo_at_max.exs` optionally accepts `STEREO_COMPARE_BUNDLES`, a
comma-separated list of absolute board bundle paths. It checks that all
files exist before changing the minimum, stops at the first failure, and
restores the original minimum/environment. Without that variable it retains
the earlier baseline/affinity comparison. Example from the board shell:

```elixir
System.put_env("STEREO_COMPARE_BUNDLES", "/root/nxiree/stereo-affinity.bin,/root/nxiree/stereo-opt-final-subgroup.bin")
try do
  Code.eval_file("/root/nxiree/compare-stereo-at-max.exs")
after
  System.delete_env("STEREO_COMPARE_BUNDLES")
end
```

Final logs and limitations: `../nx_iree/docs/reference/stereo-kernels-20261022/`
and `../nx_iree/docs/stereo-path.md` from the `c100_gpu` checkout root.
