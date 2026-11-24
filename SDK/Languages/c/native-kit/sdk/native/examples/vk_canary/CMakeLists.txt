cmake_minimum_required(VERSION 3.13)
project(vk_canary VERSION 1.0.0 LANGUAGES C CXX)

if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include("${NEXVYN_KIT}/toolchain/nexvyn-native.cmake")
if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "The Vulkan canary requires NEXVYN_WINDOWED=ON.")
endif()

set(VK_CANARY_SOURCES
  src/main.c
  src/vk_canary_stats.c
)

if(NEXVYN_VK_SHIMS)
  if(NOT EXISTS "${NEXVYN_SYSROOT}/include/vulkan/vulkan_core.h")
    message(FATAL_ERROR "Build the vulkan-headers sysroot recipe and set NEXVYN_SYSROOT.")
  endif()

  set(_vk_glslang "${NEXVYN_GLSLANG}")
  if(NOT _vk_glslang AND DEFINED ENV{NEXVYN_GLSLANG} AND NOT "$ENV{NEXVYN_GLSLANG}" STREQUAL "")
    set(_vk_glslang "$ENV{NEXVYN_GLSLANG}")
  endif()
  if(NOT _vk_glslang AND DEFINED ENV{GLSLANG_VALIDATOR} AND NOT "$ENV{GLSLANG_VALIDATOR}" STREQUAL "")
    set(_vk_glslang "$ENV{GLSLANG_VALIDATOR}")
  endif()
  if(NOT _vk_glslang)
    find_program(_vk_glslang NAMES glslangValidator glslang)
  endif()

  set(_vk_spirv_val "${NEXVYN_SPIRV_VAL}")
  if(NOT _vk_spirv_val AND DEFINED ENV{NEXVYN_SPIRV_VAL} AND NOT "$ENV{NEXVYN_SPIRV_VAL}" STREQUAL "")
    set(_vk_spirv_val "$ENV{NEXVYN_SPIRV_VAL}")
  endif()
  if(NOT _vk_spirv_val AND DEFINED ENV{SPIRV_VAL} AND NOT "$ENV{SPIRV_VAL}" STREQUAL "")
    set(_vk_spirv_val "$ENV{SPIRV_VAL}")
  endif()
  if(NOT _vk_spirv_val)
    find_program(_vk_spirv_val NAMES spirv-val)
  endif()

  if(NOT _vk_glslang OR NOT _vk_spirv_val)
    message(FATAL_ERROR
      "vk_canary with NEXVYN_VK_SHIMS=1 requires host glslangValidator and spirv-val. "
      "Set NEXVYN_GLSLANG and NEXVYN_SPIRV_VAL or put them on PATH.")
  endif()

  set(_vk_python "")
  if(DEFINED ENV{NEXVYN_PYTHON} AND EXISTS "$ENV{NEXVYN_PYTHON}")
    set(_vk_python "$ENV{NEXVYN_PYTHON}")
  else()
    find_program(_vk_python NAMES python3 python)
  endif()

  set(_vk_shader_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")
  set(_vk_shader_header "${_vk_shader_dir}/vk_canary_shaders.h")
  set(_vk_vert "${CMAKE_CURRENT_SOURCE_DIR}/shaders/triangle.vert")
  set(_vk_frag "${CMAKE_CURRENT_SOURCE_DIR}/shaders/triangle.frag")
  set(_vk_script_py "${CMAKE_CURRENT_SOURCE_DIR}/tools/compile_shaders.py")
  set(_vk_script_cmake "${CMAKE_CURRENT_SOURCE_DIR}/tools/compile_shaders.cmake")

  add_custom_command(
    OUTPUT "${_vk_shader_header}"
    COMMAND "${CMAKE_COMMAND}"
            "-DVERT=${_vk_vert}"
            "-DFRAG=${_vk_frag}"
            "-DOUT=${_vk_shader_header}"
            "-DGLSLANG=${_vk_glslang}"
            "-DSPIRV_VAL=${_vk_spirv_val}"
            "-DPYTHON_EXE=${_vk_python}"
            -P "${_vk_script_cmake}"
    DEPENDS "${_vk_vert}" "${_vk_frag}" "${_vk_script_py}" "${_vk_script_cmake}"
    COMMENT "Compiling and validating vk_canary SPIR-V shaders"
    VERBATIM
  )
  add_custom_target(vk_canary_shaders DEPENDS "${_vk_shader_header}")
endif()

nexvyn_add_windowed(${PROJECT_NAME} SOURCES ${VK_CANARY_SOURCES})

if(NEXVYN_VK_SHIMS)
  add_dependencies(${PROJECT_NAME}_objects vk_canary_shaders)
  target_include_directories(${PROJECT_NAME}_objects PRIVATE
    "${NEXVYN_SYSROOT}/include"
    "${_vk_shader_dir}"
  )
  target_compile_definitions(${PROJECT_NAME}_objects PRIVATE NEXVYN_VK_SHIMS=1)
endif()
