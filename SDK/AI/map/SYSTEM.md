# SYSTEM

## Purpose
Documents native system services (`nxn_sys.h`), power/battery state (`nxn_power.h`), threads, dynamic `.nxvlib` loading, JIT/guard-pages/fault-handlers (`nxn_jit.h`), and N4 capability limits.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_time_ns` / `nxn_time_unix` / `sleep_ns` | `nxn_sys.h` | Monotonic boot ns, UTC Unix seconds, and thread sleep |
| `nxn_thread_start` / `nxn_thread_join` | `nxn_sys.h` | App worker threads (`core` `0..2`, core 3 reserved; crash sets `nxn_should_quit`) |
| `nxn_log` / `nxn_log_write` | `nxn_sys.h` | Thread-safe logging to `System/Logs/Apps/<id>.log` |
| `nxn_power_get` / `nxn_power` | `nxn_power.h` | Fast snapshot of `percent`, `charging`, `docked`, `online` (`NXN_CAP_POWER_STATE`) |
| `nxn_notify` / `nxn_rumble` | `nxn_sys.h` | OS banner (`"notifications"` perm) and focused rumble (`1..2000` ms) |
| `nxn_clipboard_get` / `set` | `nxn_sys.h` | Shared OS UTF-8 clipboard (`NXN_CAP_CLIPBOARD`, no permission needed) |
| `nxn_perm_query` / `nxn_perm_request` | `nxn_sys.h` | Queries/re-prompts `"network"` or `"notifications"` (`NXN_CAP_PERMISSIONS`) |
| `nxn_lib_open` / `sym` / `close` | `nxn_lib.h` | Loads `.nxvlib` shared libraries (`NXN_CAP_SHARED_LIBS`, `NXN_LIB_ABI_GEN` `"1"`) |
| `nxn_jit_create` / `get` / `begin_write` / `end_write` | `nxn_jit.h` | Dual-view RW/RX JIT buffers (`NXN_CAP_JIT`, opt-in `native.windowedJit`) |
| `nxn_fault_handler_set` / `nxn_fault` | `nxn_jit.h` | Data-abort fastmem handler (`NXN_CAP_FAULT_HANDLER`, `native.windowedFaultHandler`) |
| `nxn_mem_guard` / `NXN_GUARD_*` | `nxn_jit.h` | Page-aligned guards inside app `malloc` blocks (`NXN_CAP_GUARD_PAGES`) |

## Rules
- Join all `nxn_thread_start` threads with `nxn_thread_join` before returning from entry; core 3 belongs to the system.
- N4 capability scope (host+emulator proven; device not yet measured):
  - **Threads** (start/stop/join, TLS, mutex/cond): SUPPORTED.
  - **JIT (`nxn_jit_*`)**: LIMITED (`1..64` buffers, `<= 256 MiB` total, heap-admitted, opt-in `native.windowedJit`). Cross-thread execution of published JIT code is LIMITED (workers must be joined before a rewrite).
  - **Guard pages (`nxn_mem_guard`)**: LIMITED (whole pages in app `malloc` blocks, max 32 ranges, opt-in).
  - **Fault handler (`nxn_fault_handler_set`)**: LIMITED (data aborts only; no SIMD/FPCR/`x17` edits; not a sandbox). Other fault classes, recursive faults, and safe-kill are UNSUPPORTED.
  - **Precise VM reserve/commit/decommit**: UNSUPPORTED (heap-backed compat VM). No per-app RAM guarantee.
- Always provide an interpreter / checked-memory / serial fallback when optional capabilities return `NXN_ERR_UNSUPPORTED`.

## Pitfalls
- Relying on `x17` across a potentially faulting instruction (`x17` carries the resume address and is not restored).
- Calling `nxn_*` functions or blocking inside `nxn_fault_fn`, or passing a guarded memory range to `nxn_*` / libc functions.
- Putting `nxn_pick`, `nxn_perm_request`, or `nxn_dialog` on the render thread when frames must keep running (they block waiting for the user).

## See also
- [INDEX](INDEX.md)
- [NATIVE_ABI](NATIVE_ABI.md)
- [FILES_STORAGE](FILES_STORAGE.md)
- [LIFECYCLE_WINDOW](LIFECYCLE_WINDOW.md)
