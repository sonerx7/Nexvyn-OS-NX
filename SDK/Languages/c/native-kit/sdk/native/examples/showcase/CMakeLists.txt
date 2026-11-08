cmake_minimum_required(VERSION 3.13)
project(showcase VERSION 1.0.0 LANGUAGES C CXX)

# Native SDK Showcase (README.md). One source tree, both modes:
#   python tools/nxv_native build sdk/native/examples/showcase --windowed --sysroot <sysroot>   -> build/showcase.nxvmod
#   python tools/nxv_native build sdk/native/examples/showcase --abi --sysroot <sysroot>        -> build/showcase.nro (+ greet.nxvlib)
# The sysroot (zstd, lz4, sqlite) is optional: without it those three rows show "-" (not linked).
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

set(IMGUI_DIR ${NEXVYN_KIT}/sysroot/vendor/imgui)
set(IMGUI_SRC ${IMGUI_DIR}/imgui.cpp ${IMGUI_DIR}/imgui_draw.cpp ${IMGUI_DIR}/imgui_tables.cpp ${IMGUI_DIR}/imgui_widgets.cpp
              src/imgui_gl_glue.cpp)
# third-party code: no warnings from it
set_source_files_properties(${IMGUI_SRC} PROPERTIES COMPILE_OPTIONS "-w")
set(SC_SRC src/main.cpp src/tests.cpp ${IMGUI_SRC})

# glad (the GL loader: functions come from nxn_display_proc)
set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
if(NOT EXISTS "${GLAD_LIB}")
  message(FATAL_ERROR "libglad.a not found: install the devkitPro switch-glad package")
endif()

# optional sysroot libraries
# ImGui: no fork / execvp shell helper (windowed apps cannot import them)
set(SC_LIBS "")
set(SC_DEFS IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
set(SC_INC "")
if(NEXVYN_SYSROOT AND EXISTS "${NEXVYN_SYSROOT}/lib/libzstd.a" AND EXISTS "${NEXVYN_SYSROOT}/lib/liblz4.a"
   AND EXISTS "${NEXVYN_SYSROOT}/lib/libsqlite3.a")
  set(SC_LIBS "${NEXVYN_SYSROOT}/lib/libsqlite3.a" "${NEXVYN_SYSROOT}/lib/libzstd.a" "${NEXVYN_SYSROOT}/lib/liblz4.a")
  set(SC_INC "${NEXVYN_SYSROOT}/include")
  list(APPEND SC_SRC src/libs.c)
  list(APPEND SC_DEFS SHOWCASE_LIBS=1)
  message(STATUS "showcase: zstd, lz4 and sqlite from ${NEXVYN_SYSROOT}")
else()
  message(STATUS "showcase: no sysroot (zstd / lz4 / sqlite rows will show -)")
endif()
set(SC_CXX_FLAGS -fno-rtti -fno-exceptions)

if(NEXVYN_WINDOWED)
  # a .nxvmod: -fPIC objects, nxn_* and the C library come from Nexvyn OS; the compat layer (libnexvyn_compat_pic.a) is
  # linked into the module (no nxn_lib / dlopen in 1.0)
  include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)
  nexvyn_compat_window_args(NXC_LINK NXC_LINK_OPTIONS NXC_COMPILE_OPTIONS)
  list(APPEND SC_SRC src/tests_compat.c src/nexgfx_test.cpp ${NEXVYN_KIT}/nexgfx/nexgfx_native.cpp)
  # W2a: greet.nxvlib and rtlib.nxvlib (thread_local + exceptions) ship next to the module; tests_rt.cpp needs exceptions
  nexvyn_add_lib(greet NAME greet VERSION 1.0.0 SOURCES lib/greet.c)
  nexvyn_add_lib(rtlib NAME rtlib VERSION 1.0.0 SOURCES lib/rtlib.cpp)
  list(APPEND SC_SRC src/tests_rt.cpp)
  set_source_files_properties(src/tests_rt.cpp PROPERTIES COMPILE_OPTIONS "-fexceptions;-frtti")
  nexvyn_add_windowed(showcase_win NAME showcase SOURCES ${SC_SRC} LINK ${SC_LIBS} ${GLAD_LIB} ${NXC_LINK}
                      LINK_OPTIONS ${NXC_LINK_OPTIONS})
  target_include_directories(showcase_win_objects PRIVATE ${IMGUI_DIR} ${IMGUI_DIR}/backends src ${NEXVYN_KIT}/nexgfx ${SC_INC}
                             "$ENV{DEVKITPRO}/portlibs/switch/include")
  target_include_directories(showcase_win_objects BEFORE PRIVATE "${NEXVYN_COMPAT_DIR}/include")
  target_compile_definitions(showcase_win_objects PRIVATE ${SC_DEFS} SHOWCASE_COMPAT=1)
  target_compile_options(showcase_win_objects PRIVATE ${NXC_COMPILE_OPTIONS} -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers "$<$<COMPILE_LANGUAGE:CXX>:${SC_CXX_FLAGS}>")
else()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)           # nxn_audio runs on SDL2 audio
  pkg_check_modules(GLES REQUIRED IMPORTED_TARGET glesv2 egl)     # libnexvyn_native needs EGL
  include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)
  list(APPEND SC_SRC src/tests_compat.c)
  nexvyn_add_lib(greet NAME greet VERSION 1.0.0 SOURCES lib/greet.c)
  nexvyn_add_lib(rtlib NAME rtlib VERSION 1.0.0 SOURCES lib/rtlib.cpp)
  list(APPEND SC_SRC src/tests_rt.cpp)
  set_source_files_properties(src/tests_rt.cpp PROPERTIES COMPILE_OPTIONS "-fexceptions;-frtti")
  add_executable(showcase ${SC_SRC})
  target_include_directories(showcase PRIVATE ${IMGUI_DIR} ${IMGUI_DIR}/backends src lib ${SC_INC} "$ENV{DEVKITPRO}/portlibs/switch/include")
  target_compile_definitions(showcase PRIVATE ${SC_DEFS} SHOWCASE_COMPAT=1)
  target_compile_options(showcase PRIVATE -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers "$<$<COMPILE_LANGUAGE:CXX>:${SC_CXX_FLAGS}>")
  target_link_libraries(showcase PRIVATE ${SC_LIBS} ${GLAD_LIB} PkgConfig::SDL2 PkgConfig::GLES)
  nexvyn_use_compat(showcase)
  nexvyn_export_symbols(showcase LIBS greet rtlib)
  nexvyn_add_nro(showcase TITLE "Native SDK Showcase" AUTHOR "Nexvyn OS" VERSION "1.0.0")
endif()
