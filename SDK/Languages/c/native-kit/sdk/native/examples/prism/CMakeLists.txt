cmake_minimum_required(VERSION 3.13)
project(prism VERSION 1.0.0 LANGUAGES C CXX)

# Kit location: `nxv-native build` passes -DNEXVYN_KIT=...; set it yourself when you call cmake directly.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)
pkg_check_modules(GLES REQUIRED IMPORTED_TARGET glesv2 egl)

add_executable(prism src/main.cpp)
target_link_libraries(prism PRIVATE PkgConfig::SDL2 PkgConfig::GLES)
nexvyn_add_nro(prism TITLE "Prism" AUTHOR "Nexvyn OS" VERSION "1.0.0")

# --- Nexvyn ABI: switched on with `nxv-native build --abi` (-DNEXVYN_ABI=ON) once <nexvyn/nexvyn_native.h> and
# libnexvyn_native.a exist (see the sdl2 template for details).
