cmake_minimum_required(VERSION 3.13)
project(sdl2_check VERSION 1.0.0 LANGUAGES C CXX)

# SDL2 in a Nexvyn OS window: self-test of the kit's SDL2 driver (video, GL, audio, joystick, touch, events, ...).
# Build: python tools/nxv_native build sdk/native/examples/sdl2_check   (needs the sysroot with the windowed SDL2:
# python sdk/native/sysroot/build.py sdl2-nexvyn). Package: python tools/nxv_native package sdk/native/examples/sdl2_check
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)

add_executable(sdl2_check src/main.cpp)
target_link_libraries(sdl2_check PRIVATE PkgConfig::SDL2)
nexvyn_add_nro(sdl2_check TITLE "SDL2 Check" AUTHOR "Nexvyn OS" VERSION "1.0.0")
