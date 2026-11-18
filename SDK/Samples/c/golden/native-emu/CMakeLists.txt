cmake_minimum_required(VERSION 3.13)
project(native-emu VERSION 1.0.0 LANGUAGES C CXX)
# nxv_native build supplies NEXVYN_KIT; no downloads or SDK writes here.
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
# Interpreter-only frontend; optional JIT is outside this minimal example.
nexvyn_add_windowed(native_emu_win NAME native-emu SOURCES src/main.cpp src/cpu.cpp)
