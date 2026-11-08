cmake_minimum_required(VERSION 3.13)
project(@NAME@ VERSION 1.0.0 LANGUAGES C CXX)

# Game template: building blocks, not a finished game and no ready-made menu. You get the loop (fixed time step, resize,
# focus and suspend), a GL quad batch with one shader, an action map (pad, keyboard, touch) and sound calls. Replace the
# demo in src/main.cpp with your own game and give it its own look.
#   nxv-native build <dir>      -> build/@NAME@.nxvmod (windowed or full screen: set "mode" in app.json)
#   nxv-native package <dir>    -> build/@NAME@.nxvapp
# Kit location: `nxv-native build` passes -DNEXVYN_KIT=...; set it yourself when you call cmake directly.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

# glad: the GL loader (functions come from nxn_display_proc). Need SDL2 instead? Start from the `sdl2` template.
set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
if(NOT EXISTS "${GLAD_LIB}")
  message(FATAL_ERROR "libglad.a not found: install the devkitPro switch-glad package")
endif()

nexvyn_add_windowed(@NAME@_win NAME @NAME@ SOURCES src/main.cpp LINK ${GLAD_LIB})
target_include_directories(@NAME@_win_objects PRIVATE src "$ENV{DEVKITPRO}/portlibs/switch/include")
target_compile_options(@NAME@_win_objects PRIVATE -Wall -Wextra -Wno-unused-parameter "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions>")
