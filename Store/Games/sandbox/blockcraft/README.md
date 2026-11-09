# BlockCraft



## 1.1.1 update

1.1.1: Avoids calling missing free() methods on older JavaScript SDK meshes and drops retained mesh references on session close. Includes voxel menus, recipe book, craftable filter, automatic ingredient placement, Creative search and graphics profiles. GPU initializes only on Play. Unpatched cores are refused before GPU initialization. The companion SDK 1.8 NRO isolates SDL vertex state, waits for queued GPU work before resource deletion, adds safe mesh.free() and fixes a use-after-free in invalid geometry index handling. Native safety and normal/flat world open-close-reopen checks passed in an isolated emulator profile. Physical Switch testing remains pending; the exact earlier QuickJS allocator crash was not reproduced.
