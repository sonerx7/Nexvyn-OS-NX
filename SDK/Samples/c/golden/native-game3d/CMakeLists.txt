cmake_minimum_required(VERSION 3.13)
project(native-game3d VERSION 1.0.0 LANGUAGES C CXX)
# nxv_native build supplies NEXVYN_KIT; no downloads or SDK writes here.
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
set(GLAD_LIB "$ENV{DEVKITPRO}/portlibs/switch/lib/libglad.a")
nexvyn_add_windowed(native_game_win NAME native-game3d SOURCES src/main.cpp LINK ${GLAD_LIB})
target_include_directories(native_game_win_objects PRIVATE "$ENV{DEVKITPRO}/portlibs/switch/include")
