cmake_minimum_required(VERSION 3.13)
project(services12 VERSION 1.0.0 LANGUAGES C CXX)

# Native 1.2 services sample (README in src/main.c): windowed only.
#   python tools/nxv_native build sdk/native/examples/services12 --windowed   -> build/services12.nxvmod
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "services12 is a windowed app: build with --windowed")
endif()
nexvyn_add_windowed(services12_win NAME services12 SOURCES src/main.c)
target_compile_options(services12_win_objects PRIVATE -Wall -Wextra -Wno-unused-parameter)
