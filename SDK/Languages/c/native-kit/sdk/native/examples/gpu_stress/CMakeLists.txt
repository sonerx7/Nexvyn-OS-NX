cmake_minimum_required(VERSION 3.13)
project(gpu_stress VERSION 1.0.0 LANGUAGES C CXX)

if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include("${NEXVYN_KIT}/toolchain/nexvyn-native.cmake")
if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "GPU Stress requires NEXVYN_WINDOWED=ON.")
endif()

nexvyn_add_windowed(${PROJECT_NAME} SOURCES src/main.cpp)
target_compile_features(${PROJECT_NAME}_objects PRIVATE cxx_std_17)
