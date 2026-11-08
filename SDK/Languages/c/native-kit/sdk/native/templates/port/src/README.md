Optional: files of your own that the port adds next to the upstream source (a small frontend, a launcher).
Add them in CMakeLists.txt with `target_sources(<target> PRIVATE src/your_file.c)` before `nexvyn_add_nro()`.
Delete this folder when the port needs none.
