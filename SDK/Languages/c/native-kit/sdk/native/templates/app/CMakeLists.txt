cmake_minimum_required(VERSION 3.13)
project(@NAME@ VERSION 1.0.0 LANGUAGES C CXX)

# App template: a small real UI app (file picker, settings, lang/*.json, the OS look from nxn_ui tokens).
#   nxv-native build <dir>      -> build/@NAME@.nxvmod (windowed; the same build runs full screen)
#   nxv-native package <dir>    -> build/@NAME@.nxvapp
# Kit location: `nxv-native build` passes -DNEXVYN_KIT=...; set it yourself when you call cmake directly.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

# Dear ImGui from the kit (the widget layer of this template; replace it with your own if you like). The default shell
# helpers (fork / execvp) are off: a windowed app cannot import them.
set(IMGUI_DIR ${NEXVYN_KIT}/sysroot/vendor/imgui)
set(IMGUI_SRC ${IMGUI_DIR}/imgui.cpp ${IMGUI_DIR}/imgui_draw.cpp ${IMGUI_DIR}/imgui_tables.cpp ${IMGUI_DIR}/imgui_widgets.cpp
              src/imgui_gl_glue.cpp)
set_source_files_properties(${IMGUI_SRC} PROPERTIES COMPILE_OPTIONS "-w")  # third-party code: no warnings from it

set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
if(NOT EXISTS "${GLAD_LIB}")
  message(FATAL_ERROR "libglad.a not found: install the devkitPro switch-glad package")
endif()

nexvyn_add_windowed(@NAME@_win NAME @NAME@ SOURCES src/main.cpp ${IMGUI_SRC} LINK ${GLAD_LIB})
target_include_directories(@NAME@_win_objects PRIVATE ${IMGUI_DIR} ${IMGUI_DIR}/backends
                           "$ENV{DEVKITPRO}/portlibs/switch/include")
target_compile_definitions(@NAME@_win_objects PRIVATE IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
target_compile_options(@NAME@_win_objects PRIVATE -Wall -Wextra -Wno-unused-parameter "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions>")
