cmake_minimum_required(VERSION 3.13)
project(thread_timing VERSION 1.0.0 LANGUAGES C CXX)

# Thread Timing (README.md): timing of sleeps, timed waits, wait-on-address and JIT write cost.
#   python tools/nxv_native build sdk/native/examples/thread_timing --windowed   -> build/thread_timing.nxvmod
#   python tools/nxv_native build sdk/native/examples/thread_timing              -> stand-alone NRO
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
add_executable(thread_timing src/main.c)
target_compile_options(thread_timing PRIVATE -Wall -Wextra -Werror)
nexvyn_add_nro(thread_timing TITLE "Thread Timing" AUTHOR "Nexvyn OS"
               VERSION "1.0.0" ICON "${CMAKE_CURRENT_SOURCE_DIR}/icon.png")
if(NEXVYN_WINDOWED)
  target_compile_options(thread_timing_windowed_objects PRIVATE -Wall -Wextra -Werror)
else()
  # The stand-alone implementation of nxn_audio and nxn_display uses these backends.
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(TT_SDL REQUIRED IMPORTED_TARGET sdl2)
  target_link_libraries(thread_timing PRIVATE PkgConfig::TT_SDL)
endif()
