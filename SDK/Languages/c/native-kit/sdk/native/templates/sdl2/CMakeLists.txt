cmake_minimum_required(VERSION 3.13)
project(@NAME@ VERSION 1.0.0 LANGUAGES C CXX)

# Kit location: `nxv-native build` passes -DNEXVYN_KIT=...; set it yourself when you call cmake directly.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)

add_executable(@NAME@ src/main.cpp)
target_link_libraries(@NAME@ PRIVATE PkgConfig::SDL2)
nexvyn_add_nro(@NAME@ TITLE "@TITLE@" AUTHOR "Unknown" VERSION "1.0.0")

# --- Nexvyn ABI: switched on with `nxv-native build --abi` (-DNEXVYN_ABI=ON) once <nexvyn/nexvyn_native.h> and
# libnexvyn_native.a exist. nexvyn_add_nro() then adds the include dir, links -lnexvyn_native and defines NEXVYN_ABI,
# so the `#ifdef NEXVYN_ABI` code in src/ starts compiling. Nothing else to change.
