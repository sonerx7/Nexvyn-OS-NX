# Dear ImGui 1.91.5 (MIT, see LICENSE.txt) with the SDL2 and OpenGL ES backends.
# Use from a project:
#   add_subdirectory(${NEXVYN_KIT}/sysroot/vendor/imgui imgui)
#   target_link_libraries(mygame PRIVATE imgui)
# The OpenGL backend is built for GLES 3 (IMGUI_IMPL_OPENGL_ES3); use ES2 instead by changing the define below.
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET GLOBAL sdl2)
pkg_check_modules(GLES REQUIRED IMPORTED_TARGET GLOBAL glesv2 egl)

add_library(imgui STATIC
  imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp
  backends/imgui_impl_sdl2.cpp backends/imgui_impl_opengl3.cpp)
target_include_directories(imgui PUBLIC ${CMAKE_CURRENT_LIST_DIR} ${CMAKE_CURRENT_LIST_DIR}/backends)
# no shell on the console: ImGui's default "open URL" would call fork / execvp
target_compile_definitions(imgui PUBLIC IMGUI_IMPL_OPENGL_ES3 IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
target_link_libraries(imgui PUBLIC PkgConfig::SDL2 PkgConfig::GLES)
