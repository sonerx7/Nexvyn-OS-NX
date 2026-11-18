cmake_minimum_required(VERSION 3.13)
project(native-port VERSION 1.0.0 LANGUAGES C CXX)
# nxv_native build supplies NEXVYN_KIT; no downloads or SDK writes here.
set(NEXVYN_ABI ON CACHE BOOL "" FORCE)
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
# Set PORT_SRC in a local integration to use a separately obtained upstream tree.
if(NOT DEFINED PORT_SRC)
  set(PORT_SRC "${CMAKE_CURRENT_LIST_DIR}/example-upstream")
endif()
add_subdirectory(${PORT_SRC} upstream EXCLUDE_FROM_ALL)
nexvyn_add_nro(native-port TITLE "Native Port" AUTHOR "SDK examples" VERSION "1.0.0")
