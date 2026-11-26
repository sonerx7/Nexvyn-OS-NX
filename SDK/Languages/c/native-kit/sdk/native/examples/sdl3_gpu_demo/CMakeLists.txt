cmake_minimum_required(VERSION 3.13)
project(sdl3_gpu_demo VERSION 1.0.0 LANGUAGES C)

# SDL3 GPU API demo on the Nexvyn Vulkan 1.3 driver (windowed .nxvmod).
# Requires the sdl3-nexvyn sysroot recipe: python sdk/native/sysroot/build.py sdl3-nexvyn
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include("${NEXVYN_KIT}/toolchain/nexvyn-native.cmake")
if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "sdl3_gpu_demo requires NEXVYN_WINDOWED=ON.")
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL3 REQUIRED IMPORTED_TARGET sdl3)

add_executable(sdl3_gpu_demo src/main.c)
target_link_libraries(sdl3_gpu_demo PRIVATE PkgConfig::SDL3)
nexvyn_add_nro(sdl3_gpu_demo TITLE "SDL3 GPU Demo" AUTHOR "Nexvyn OS" VERSION "1.0.0")
