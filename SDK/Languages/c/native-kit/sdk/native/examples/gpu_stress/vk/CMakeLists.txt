cmake_minimum_required(VERSION 3.13)
project(gpu_stress VERSION 1.0.0 LANGUAGES C CXX)

# Vulkan variant of the GL gpu_stress load app (N5-H.2). Reuses the vk_canary shader pipeline.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
endif()
include("${NEXVYN_KIT}/toolchain/nexvyn-native.cmake")
if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "GPU Stress requires NEXVYN_WINDOWED=ON.")
endif()
if(NOT NEXVYN_VK_SHIMS)
  message(FATAL_ERROR "GPU Stress (Vulkan) requires NEXVYN_VK_SHIMS=1.")
endif()
if(NOT EXISTS "${NEXVYN_SYSROOT}/include/vulkan/vulkan_core.h")
  message(FATAL_ERROR "Build the vulkan-headers sysroot recipe and set NEXVYN_SYSROOT.")
endif()

set(_vk_glslang "${NEXVYN_GLSLANG}")
if(NOT _vk_glslang AND DEFINED ENV{NEXVYN_GLSLANG})
  set(_vk_glslang "$ENV{NEXVYN_GLSLANG}")
endif()
if(NOT _vk_glslang)
  find_program(_vk_glslang NAMES glslangValidator glslang)
endif()
set(_vk_spirv_val "${NEXVYN_SPIRV_VAL}")
if(NOT _vk_spirv_val AND DEFINED ENV{NEXVYN_SPIRV_VAL})
  set(_vk_spirv_val "$ENV{NEXVYN_SPIRV_VAL}")
endif()
if(NOT _vk_spirv_val)
  find_program(_vk_spirv_val NAMES spirv-val)
endif()
if(NOT _vk_glslang OR NOT _vk_spirv_val)
  message(FATAL_ERROR "Set NEXVYN_GLSLANG and NEXVYN_SPIRV_VAL or put them on PATH.")
endif()
set(_vk_python "")
if(DEFINED ENV{NEXVYN_PYTHON} AND EXISTS "$ENV{NEXVYN_PYTHON}")
  set(_vk_python "$ENV{NEXVYN_PYTHON}")
else()
  find_program(_vk_python NAMES python3 python)
endif()

set(_tools "${CMAKE_CURRENT_LIST_DIR}/../../vk_canary/tools")
set(_vk_shader_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(_vk_shader_header "${_vk_shader_dir}/vk_canary_shaders.h")
set(_vk_vert "${CMAKE_CURRENT_SOURCE_DIR}/shaders/stress.vert")
set(_vk_frag "${CMAKE_CURRENT_SOURCE_DIR}/shaders/stress.frag")
add_custom_command(
  OUTPUT "${_vk_shader_header}"
  COMMAND "${CMAKE_COMMAND}" "-DVERT=${_vk_vert}" "-DFRAG=${_vk_frag}" "-DOUT=${_vk_shader_header}"
          "-DGLSLANG=${_vk_glslang}" "-DSPIRV_VAL=${_vk_spirv_val}" "-DPYTHON_EXE=${_vk_python}"
          -P "${_tools}/compile_shaders.cmake"
  DEPENDS "${_vk_vert}" "${_vk_frag}" "${_tools}/compile_shaders.py" "${_tools}/compile_shaders.cmake"
  COMMENT "Compiling and validating gpu_stress SPIR-V shaders"
  VERBATIM
)
add_custom_target(gpu_stress_shaders DEPENDS "${_vk_shader_header}")

nexvyn_add_windowed(${PROJECT_NAME} SOURCES src/main.c)
add_dependencies(${PROJECT_NAME}_objects gpu_stress_shaders)
target_include_directories(${PROJECT_NAME}_objects PRIVATE "${NEXVYN_SYSROOT}/include" "${_vk_shader_dir}")
target_compile_definitions(${PROJECT_NAME}_objects PRIVATE NEXVYN_VK_SHIMS=1)
