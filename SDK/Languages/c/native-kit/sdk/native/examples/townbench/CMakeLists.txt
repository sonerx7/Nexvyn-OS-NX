cmake_minimum_required(VERSION 3.13)
project(townbench VERSION 1.0.0 LANGUAGES C CXX)

# Village Bench: windowed only.
#   python tools/nxv_native build sdk/native/examples/townbench --windowed   -> build/townbench.nxvmod
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

set(IMGUI_DIR ${NEXVYN_KIT}/sysroot/vendor/imgui)
set(IMGUI_SRC ${IMGUI_DIR}/imgui.cpp ${IMGUI_DIR}/imgui_draw.cpp ${IMGUI_DIR}/imgui_tables.cpp ${IMGUI_DIR}/imgui_widgets.cpp src/imgui_gl_glue.cpp)
set_source_files_properties(${IMGUI_SRC} PROPERTIES COMPILE_OPTIONS "-w")

set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
if(NOT EXISTS "${GLAD_LIB}")
  message(FATAL_ERROR "libglad.a not found: install the devkitPro switch-glad package")
endif()

if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "townbench is a windowed app: build with --windowed")
endif()
# NexGFX (include/nexvyn/nexgfx_native.h) is built into the app: its source is part of the kit.
set(NEXGFX_SRC ${NEXVYN_KIT}/nexgfx/nexgfx_native.cpp)
nexvyn_add_windowed(townbench_win NAME townbench SOURCES src/main.cpp ${IMGUI_SRC} ${NEXGFX_SRC} LINK ${GLAD_LIB})
target_include_directories(townbench_win_objects PRIVATE ${IMGUI_DIR} ${IMGUI_DIR}/backends src ${NEXVYN_KIT}/nexgfx "$ENV{DEVKITPRO}/portlibs/switch/include")
target_compile_definitions(townbench_win_objects PRIVATE IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
target_compile_options(townbench_win_objects PRIVATE -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions>")
