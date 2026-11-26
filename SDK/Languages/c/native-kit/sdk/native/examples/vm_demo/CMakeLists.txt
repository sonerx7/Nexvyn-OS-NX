cmake_minimum_required(VERSION 3.13)
project(vm_demo LANGUAGES C CXX)

if(NOT DEFINED NEXVYN_KIT OR NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "Build vm_demo with the Native SDK's windowed build tool")
endif()
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
nexvyn_add_windowed(vm_demo SOURCES src/main.c)
target_compile_options(vm_demo_objects PRIVATE -Wall -Wextra -Werror)
