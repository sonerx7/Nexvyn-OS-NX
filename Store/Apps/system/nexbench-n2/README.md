# NexBench N2

Deterministic 5-phase system benchmark and 475,000+ polygon NexGFX PBR 3D showcase for Nexvyn OS N2 (`SDK 2.0 / 1.13`).

- **Phase 1:** CPU & Lua 5.4.7 Generational GC math workload
- **Phase 2:** Storage, JSON & Memory I/O throughput
- **Phase 3:** 2D NexGFX vector/particle & NXUI retained layout stress
- **Phase 4:** 3D instanced geometry (`g3d.drawInstanced`)
- **Phase 5:** 475K+ polygon NexGFX PBR arena (`WARDEN_A.glb` x24 + `MaintenanceDrone_A.glb` x8) with real-time lights, shadows, ACES tone mapping, and bloom

Runs in ~52 seconds with live FPS, frame time (ms), triangle count, and RAM telemetry, saving every run locally for release-to-release comparison.
