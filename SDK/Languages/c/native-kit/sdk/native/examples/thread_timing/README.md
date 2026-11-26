# Thread Timing

Measures CPU info, timer resolution, sleep and wait accuracy, wake-up latency, and JIT W^X write-cycle cost in one run.

## What it measures

- `nxn_cpu_info_get`: fixed Cortex-A57 features, `CTR_EL0` cache line sizes, process core mask, and app worker core mask (cores 1-2).
- `nxn_time_ns`: smallest observed non-zero step across 1,000 back-to-back calls and average call cost.
- `nxn_sleep_ns`, `pthread_cond_timedwait`, and `svcWaitForAddress`: overshoot (`p50`, `p95`, `max` in us) across 40 samples each for `100 us` to `10 ms`.
- Worker-to-main wake-up latency for `pthread_cond_signal` and `svcSignalToAddress` (40 samples, ~1 ms interval).
- `nxn_jit_begin_write` / `nxn_jit_end_write`: `p50`, `p95`, `max` in us for `4 KiB`, `64 KiB`, and `1 MiB` buffers when `native.windowedJit` is enabled (otherwise reports `THRT jit status=unsupported rc=-2`).

## Build and run

```sh
python tools/nxv_native build sdk/native/examples/thread_timing --windowed
python tools/nxv_native package sdk/native/examples/thread_timing
```

Output is logged with `THRT key=value` lines ending in `THRT END` and saved to `thread_timing.txt` inside the app data folder (`NXN_DIR_DATA`).
