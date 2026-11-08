# Nexvyn native SDK: CMake toolchain file for devkitA64 + libnx (Switch, AArch64).
#
#   cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=<kit>/toolchain/nexvyn-switch.cmake
#
# What it does on top of devkitPro's own Switch.cmake:
#   - C11 / C++17, -O2 for Release, exceptions and RTTI ON (ports need them)
#   - adds the Nexvyn sysroot (extra libraries built by sysroot/assemble.py) to the search paths
#   - nothing else: the project then calls nexvyn_add_nro() from nexvyn-native.cmake to get the .nro

if(NOT DEFINED ENV{DEVKITPRO})
  # devkitPro's msys2 shell and the CI image both set it; /opt/devkitpro is the pacman default
  set(ENV{DEVKITPRO} /opt/devkitpro)
endif()
set(DEVKITPRO "$ENV{DEVKITPRO}")
if(NOT EXISTS "${DEVKITPRO}/cmake/Switch.cmake")
  message(FATAL_ERROR "devkitPro not found at ${DEVKITPRO} (set DEVKITPRO, run inside the devkitPro shell)")
endif()

# Optional extra prefix with libraries the portlibs do not ship (OpenAL, libarchive, sqlite, ...).
# Created by sysroot/assemble.py; skipped when it does not exist.
if(NOT DEFINED NEXVYN_SYSROOT AND DEFINED ENV{NEXVYN_SYSROOT})
  set(NEXVYN_SYSROOT "$ENV{NEXVYN_SYSROOT}")
endif()

include("${DEVKITPRO}/cmake/Switch.cmake")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)    # gnu11: POSIX names stay visible in newlib headers
set(CMAKE_CXX_EXTENSIONS ON)

# Ports need exceptions and RTTI (the libnx default builds leave them on, state it so nobody turns them off by accident).
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -fexceptions -frtti")
# Frame pointers: crash reports walk the x29 chain to print a backtrace (docs/NATIVE_GUIDE.en.md "Reading a crash report").
# cmake -DNEXVYN_FRAME_POINTER=OFF drops them (the cost is measured in docs/NATIVE_KIT.en.md).
option(NEXVYN_FRAME_POINTER "Keep the frame pointer (crash backtraces)" ON)
if(NEXVYN_FRAME_POINTER)
  # aarch64 gcc already keeps a frame record in every non-leaf function, so -fno-omit-frame-pointer alone changes nothing;
  # -mno-omit-leaf-frame-pointer is the part that adds one to leaf functions (the caller of a crashing leaf stays on the chain)
  add_compile_options(-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer)  # (the Switch.cmake flags are cache entries: *_FLAGS_INIT would not reach them)
endif()
set(CMAKE_C_FLAGS_RELEASE_INIT "-O2")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "-O2")
set(CMAKE_C_FLAGS_DEBUG_INIT "-O0 -g")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "-O0 -g")

if(NEXVYN_SYSROOT AND IS_DIRECTORY "${NEXVYN_SYSROOT}")
  list(APPEND CMAKE_PREFIX_PATH "${NEXVYN_SYSROOT}")
  list(APPEND CMAKE_FIND_ROOT_PATH "${NEXVYN_SYSROOT}")
  set(ENV{PKG_CONFIG_PATH} "${NEXVYN_SYSROOT}/lib/pkgconfig")
  include_directories(SYSTEM "${NEXVYN_SYSROOT}/include")
  link_directories("${NEXVYN_SYSROOT}/lib")
endif()
