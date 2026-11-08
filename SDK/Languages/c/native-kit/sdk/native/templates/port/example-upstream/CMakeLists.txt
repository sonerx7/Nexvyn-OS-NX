# Stand-in for an upstream project: a plain CMake project that finds SDL2 the usual way. Replace it by running fetch.py
# (the real source goes to ../upstream and this folder is then ignored); delete it once your port builds.
cmake_minimum_required(VERSION 3.13)
project(upstream_example C)
find_package(SDL2 CONFIG REQUIRED)
add_executable(@NAME@ main.c)
target_link_libraries(@NAME@ PRIVATE SDL2::SDL2)
