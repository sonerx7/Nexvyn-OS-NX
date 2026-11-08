# Sysroot proof: calls every library of the Nexvyn overlay sysroot once. Build with the kit toolchain:
#   cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=<repo>/sdk/native/toolchain/nexvyn-switch.cmake
# NEXVYN_SYSROOT (env or -D) must point to build/native-sysroot. A library whose .a is missing is left out of the test.
cmake_minimum_required(VERSION 3.13)
project(sysroot_test C CXX)  # CXX: OpenAL Soft is C++, the link needs libstdc++
include(${CMAKE_CURRENT_LIST_DIR}/../../../toolchain/nexvyn-native.cmake)

if(NOT NEXVYN_SYSROOT)
  message(FATAL_ERROR "set NEXVYN_SYSROOT to the built sysroot (build/native-sysroot)")
endif()

add_executable(sysroot_test source/main.c)
foreach(_l zstd lz4 sqlite3 archive openal iconv pixman-1 glib-2.0)
  if(EXISTS "${NEXVYN_SYSROOT}/lib/lib${_l}.a")
    string(TOUPPER "${_l}" _u)
    string(REGEX REPLACE "[^A-Z0-9]" "_" _u "${_u}")
    target_compile_definitions(sysroot_test PRIVATE HAVE_${_u}=1)
  endif()
endforeach()
target_include_directories(sysroot_test PRIVATE "${NEXVYN_SYSROOT}/include"
  "${NEXVYN_SYSROOT}/include/glib-2.0" "${NEXVYN_SYSROOT}/lib/glib-2.0/include"
  "${NEXVYN_SYSROOT}/include/pixman-1" "$ENV{DEVKITPRO}/portlibs/switch/include")
target_link_directories(sysroot_test PRIVATE "${NEXVYN_SYSROOT}/lib")

# Link order: users first, then what they need. Optional libraries are added only when built.
set(_link "")
foreach(_l glib-2.0 pcre2-8 ffi pixman-1 openal archive iconv sqlite3 zstd lz4)
  if(EXISTS "${NEXVYN_SYSROOT}/lib/lib${_l}.a")
    list(APPEND _link ${_l})
  endif()
endforeach()
if(EXISTS "${NEXVYN_SYSROOT}/lib/libarchive.a")
  list(APPEND _link mbedcrypto bz2)
endif()
target_link_libraries(sysroot_test PRIVATE ${_link} SDL2 EGL GLESv2 glapi drm_nouveau z m nx)
# glib's main loop needs pipe()/poll() style POSIX calls newlib lacks: the compat layer (sdk/native/compat) supplies them.
# Used when it is in the kit (merged tree) or when -DNEXVYN_COMPAT_DIR=<path to compat/> points at one.
if(NOT NEXVYN_COMPAT_DIR)
  set(NEXVYN_COMPAT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../compat")
endif()
if(EXISTS "${NEXVYN_COMPAT_DIR}/nexvyn-compat.cmake")
  include("${NEXVYN_COMPAT_DIR}/nexvyn-compat.cmake")
  nexvyn_use_compat(sysroot_test)
  target_compile_definitions(sysroot_test PRIVATE NEXVYN_COMPAT=1)
  message(STATUS "sysroot_test: compat layer from ${NEXVYN_COMPAT_DIR}")
else()
  message(STATUS "sysroot_test: no compat layer, the glib main loop part is left out")
endif()
set_target_properties(sysroot_test PROPERTIES LINKER_LANGUAGE CXX)
nexvyn_add_nro(sysroot_test TITLE "Sysroot Test" AUTHOR "Nexvyn" VERSION "1.0.0")
