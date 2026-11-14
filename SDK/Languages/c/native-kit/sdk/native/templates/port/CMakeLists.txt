cmake_minimum_required(VERSION 3.13)
project(@NAME@ VERSION 1.0.0 LANGUAGES C CXX)

# Port template: put an existing CMake project on the Nexvyn target without forking it. This folder holds only the glue:
#   fetch.py        gets the upstream source at a pinned tag + commit into ./upstream and applies patches/*.patch
#   CMakeLists.txt  this file: toolchain, kit libraries, the upstream project as a subdirectory, the Nexvyn target
#   patches/        the changes the upstream source needs (small, one reason each; the README there says how to write them)
#   app.json        the package: id, name, window size, permissions
# The pattern comes from sdk/native/ports/chocolate-doom (SDL2 + SDL2_mixer) and sdk/native/ports/mgba (own frontend).
#   python fetch.py
#   nxv-native build <dir> --sysroot <sysroot with windowed/>      -> build/@NAME@.nxvmod
#   nxv-native package <dir>                                        -> build/@NAME@.nxvapp
# Ship the upstream licence and source link inside the package (docs/NATIVE_GUIDE.md, "Ports"): a port is its own
# program, installed from the App Market, never linked into Nexvyn OS. No BIOS, firmware, system files or game data.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
# Optional compatibility layer for POSIX calls newlib lacks (mmap flags, ucontext, eventfd, dlfcn ...; case-insensitive
# paths). Build it once with `make -C <kit>/compat` (devkitPro shell), then turn on the two commented lines below.
# include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)

# 1. The upstream source (fetch.py puts it in ./upstream; pass -DPORT_SRC=... to use another checkout). Until you fetch
#    one, ./example-upstream (a few lines of SDL2 code with its own CMakeLists.txt) stands in, so the template builds as is.
if(NOT DEFINED PORT_SRC)
  if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/upstream/CMakeLists.txt")
    set(PORT_SRC "${CMAKE_CURRENT_LIST_DIR}/upstream")
  else()
    set(PORT_SRC "${CMAKE_CURRENT_LIST_DIR}/example-upstream")
    message(STATUS "port: no ./upstream yet (python fetch.py), building the stand-in ./example-upstream")
  endif()
endif()
if(NOT EXISTS "${PORT_SRC}/CMakeLists.txt")
  message(FATAL_ERROR "upstream source not found in ${PORT_SRC}: run `python fetch.py` first")
endif()

# 2. Switch off what the target cannot do (names are the upstream project's own options): networking, JIT, optional
#    audio / video libraries that are not in the kit, tests, installers. Examples from the reference ports:
#      set(ENABLE_SDL2_NET OFF CACHE BOOL "" FORCE)
#      set(CMAKE_DISABLE_FIND_PACKAGE_FluidSynth ON)
# (none by default)

# 3. The kit's libraries. SDL2 comes from <sysroot>/windowed (the SDL2 with Nexvyn OS drivers); static only. Config
#    packages name the targets SDL2::SDL2-static: make the usual names point to them when the upstream links SDL2::SDL2.
find_package(SDL2 CONFIG QUIET)
if(TARGET SDL2::SDL2-static)
  set_target_properties(SDL2::SDL2-static PROPERTIES IMPORTED_GLOBAL TRUE)
  if(NOT TARGET SDL2::SDL2)
    add_library(SDL2::SDL2 ALIAS SDL2::SDL2-static)
  endif()
endif()

# 4. The upstream project. EXCLUDE_FROM_ALL: only the target named below is built.
add_subdirectory(${PORT_SRC} upstream EXCLUDE_FROM_ALL)

# 5. The Nexvyn target. Set PORT_TARGET to the upstream executable target (the name in its add_executable()).
#    nexvyn_add_nro() builds it as the windowed module build/<target>.nxvmod; the package main is "<project name>.nxvmod",
#    so PORT_TARGET and project(@NAME@) must be the same name: rename with set_target_properties(... OUTPUT_NAME) if not.
set(PORT_TARGET "@NAME@")
if(TARGET ${PORT_TARGET})
  # nexvyn_use_compat(${PORT_TARGET})   # with the compat layer included above
  nexvyn_add_nro(${PORT_TARGET} TITLE "@TITLE@" AUTHOR "Upstream authors (port: you)" VERSION "1.0.0")
else()
  message(FATAL_ERROR "target ${PORT_TARGET} does not exist in the upstream project: set PORT_TARGET in CMakeLists.txt")
endif()
