#!/usr/bin/env bash
# Bound native Vulkan diagnostics and stop on new L4T GPU errors.
set -euo pipefail
if (( $# < 2 )); then echo 'usage: l4t_vulkan_probe.sh OUTPUT_DIR COMMAND [ARGS...]' >&2; exit 2; fi
probe_output=$1
shift
mkdir "$probe_output"
probe_pid=
probe_status=0
probe_timeout=${C100_GPU_TIMEOUT_SECONDS:-90}
if ! [[ "$probe_timeout" =~ ^[1-9][0-9]*$ ]] || (( probe_timeout > 90 )); then
  echo 'C100_GPU_TIMEOUT_SECONDS must be 1..90' >&2; exit 2
fi
probe_error_pattern='(nvgpu|NVRM|gk20a|host1x|nvhost).*(timeout|timed out|fault|Xid|fatal|failed|error)'
probe_stop() {
  if [[ -n "$probe_pid" ]] && kill -0 "$probe_pid" 2>/dev/null; then
    kill -TERM -- "-$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null || true
  fi
}
trap probe_stop EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
dmesg > "$probe_output/dmesg-before.log"
probe_baseline_lines=$(wc -l < "$probe_output/dmesg-before.log")
if grep -Ei "$probe_error_pattern" "$probe_output/dmesg-before.log" > "$probe_output/baseline-gpu-errors.log"; then
  echo 'GPU errors already present; refusing probe' >&2
  exit 1
fi
printf 'wall_ms,cpu_khz,gpu_hz,emc_hz,available_kb\n' > "$probe_output/frequency.csv"
probe_sample() {
  local probe_temp probe_available probe_lines
  dmesg > "$probe_output/dmesg-current.log"
  probe_lines=$(wc -l < "$probe_output/dmesg-current.log")
  if (( probe_lines < probe_baseline_lines )); then echo 'kernel log was truncated' >&2; return 1; fi
  if tail -n "+$((probe_baseline_lines+1))" "$probe_output/dmesg-current.log" | grep -Ei "$probe_error_pattern" > "$probe_output/new-gpu-errors.log"; then
    echo 'new GPU error; stopping' >&2; return 1
  fi
  for probe_file in /sys/class/thermal/thermal_zone*/temp; do
    read -r probe_temp < "$probe_file"
    if (( probe_temp >= 70000 )); then echo 'thermal guard' >&2; return 1; fi
  done
  probe_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  if (( probe_available < 1500000 )); then echo 'memory headroom guard' >&2; return 1; fi
  printf '%s,%s,%s,%s,%s\n' "$(date +%s%3N)" \
    "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq)" \
    "$(cat /sys/class/devfreq/57000000.gpu/cur_freq)" \
    "$(cat /sys/kernel/debug/clk/emc/clk_rate)" "$probe_available" >> "$probe_output/frequency.csv"
}
probe_sample
setsid --wait timeout --signal=TERM --kill-after=2s "${probe_timeout}s" "$@" > "$probe_output/child.log" 2>&1 &
probe_pid=$!
while kill -0 "$probe_pid" 2>/dev/null; do
  if ! probe_sample; then probe_status=1; probe_stop; break; fi
  sleep 0.25
done
if (( probe_status == 0 )); then wait "$probe_pid" || probe_status=$?; fi
probe_pid=
probe_sample || probe_status=1
cat "$probe_output/child.log"
printf 'CHILD_EXIT=%s\n' "$probe_status"
if (( probe_status != 0 )); then exit "$probe_status"; fi
printf 'NEW_GPU_ERRORS=0\nL4T_VULKAN_PROBE_PASS\n'
