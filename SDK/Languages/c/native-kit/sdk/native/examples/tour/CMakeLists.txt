cmake_minimum_required(VERSION 3.13)
project(tour VERSION 1.0.0 LANGUAGES C CXX)

# Native Tour (README.md): windowed only, one source tree.
#   python tools/nxv_native build sdk/native/examples/tour     -> build/tour.nxvmod + build/tourlib.nxvlib
#   python tools/nxv_native package sdk/native/examples/tour   -> build/tour.nxvapp
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)

set(IMGUI_DIR ${NEXVYN_KIT}/sysroot/vendor/imgui)
set(IMGUI_SRC ${IMGUI_DIR}/imgui.cpp ${IMGUI_DIR}/imgui_draw.cpp ${IMGUI_DIR}/imgui_tables.cpp ${IMGUI_DIR}/imgui_widgets.cpp
              src/imgui_gl_glue.cpp)
set_source_files_properties(${IMGUI_SRC} PROPERTIES COMPILE_OPTIONS "-w")  # third-party code: no warnings from it

set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
if(NOT EXISTS "${GLAD_LIB}")
  message(FATAL_ERROR "libglad.a not found: install the devkitPro switch-glad package")
endif()

if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "tour is a windowed app: build with nxv-native build (windowed is the default)")
endif()
# the compat layer (exceptions and threads in a window) and NexGFX (its source is part of the kit)
include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)
nexvyn_compat_window_args(NXC_LINK NXC_LINK_OPTIONS NXC_COMPILE_OPTIONS)
set(NEXGFX_SRC ${NEXVYN_KIT}/nexgfx/nexgfx_native.cpp)

# tourlib.nxvlib: thread_local, a greeting and exceptions in a shared library (ships next to the module)
nexvyn_add_lib(tourlib NAME tourlib VERSION 1.0.0 SOURCES lib/tourlib.cpp)

# only tour_rt.cpp throws and catches: it alone is built with exceptions (the rest of the app has none)
set_source_files_properties(src/tour_rt.cpp PROPERTIES COMPILE_OPTIONS "-fexceptions;-frtti")
nexvyn_add_windowed(tour_win NAME tour SOURCES src/main.cpp src/tour_rt.cpp ${IMGUI_SRC} ${NEXGFX_SRC}
                    LINK ${GLAD_LIB} ${NXC_LINK} LINK_OPTIONS ${NXC_LINK_OPTIONS})
target_include_directories(tour_win_objects PRIVATE ${IMGUI_DIR} ${IMGUI_DIR}/backends src ${NEXVYN_KIT}/nexgfx
                           "$ENV{DEVKITPRO}/portlibs/switch/include")
target_include_directories(tour_win_objects BEFORE PRIVATE "${NEXVYN_COMPAT_DIR}/include")
target_compile_definitions(tour_win_objects PRIVATE IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
target_compile_options(tour_win_objects PRIVATE ${NXC_COMPILE_OPTIONS} -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers
                       "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions>")
