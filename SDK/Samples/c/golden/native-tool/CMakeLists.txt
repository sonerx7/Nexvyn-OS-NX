cmake_minimum_required(VERSION 3.13)
project(native-tool VERSION 1.0.0 LANGUAGES C)

# A shared library (greet.nxvlib) and an app that loads it at run time (docs/NATIVE_KIT.md, "Shared libraries").
# Static linking stays the default; a .nxvlib is for code many apps share or that is loaded as a plugin.
#   python tools/nxv_native build .      -> build/native-tool.nxvmod + build/greet.nxvlib (checked: -fPIC, no text relocations)
#   python tools/nxv_native package .    -> the .nxvapp carries greet.nxvlib next to the module
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
# nxn_lib_open lives in libnexvyn_native (make -C <kit>/lib)
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

# 1. the library: only C functions cross the boundary (lib/greet.h)
nexvyn_add_lib(greet NAME greet VERSION 1.0.0 SOURCES lib/greet.c)

# 2. the app: exports libc / libnx to the library (one newlib, one heap) and loads it with nxn_lib_open
add_executable(native-tool src/main.c)
target_include_directories(native-tool PRIVATE lib)
nexvyn_export_symbols(native-tool LIBS greet)
nexvyn_add_nro(native-tool TITLE "Native Tool" AUTHOR "Unknown" VERSION "1.0.0")
