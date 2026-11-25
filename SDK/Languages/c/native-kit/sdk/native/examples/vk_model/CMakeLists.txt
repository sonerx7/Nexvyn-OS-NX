cmake_minimum_required(VERSION 3.13)
project(vk_model VERSION 1.0.0 LANGUAGES C CXX)

# Vulkan Model (README.md): windowed only, Vulkan shims on, Dear ImGui Vulkan overlay.
# The model is not part of the source: tools/package.py bakes an FBX into data/model.nxvmesh of the package.
if(NOT DEFINED NEXVYN_KIT)
  get_filename_component(NEXVYN_KIT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
endif()
include("${NEXVYN_KIT}/toolchain/nexvyn-native.cmake")
if(NOT NEXVYN_WINDOWED)
  message(FATAL_ERROR "vk_model requires NEXVYN_WINDOWED=ON.")
endif()

set(VK_MODEL_SOURCES src/main.cpp)

if(NEXVYN_VK_SHIMS)
  if(NOT EXISTS "${NEXVYN_SYSROOT}/include/vulkan/vulkan_core.h")
    message(FATAL_ERROR "Build the vulkan-headers sysroot recipe and set NEXVYN_SYSROOT.")
  endif()
  # Same option names as sysroot/vendor/imgui: the Vulkan backend comes from Dear ImGui 1.91.5 (not in the kit).
  set(NEXVYN_IMGUI_VULKAN ON)
  if(NOT NEXVYN_IMGUI_VULKAN_BACKENDS AND DEFINED ENV{NEXVYN_IMGUI_VULKAN_BACKENDS})
    set(NEXVYN_IMGUI_VULKAN_BACKENDS "$ENV{NEXVYN_IMGUI_VULKAN_BACKENDS}")
  endif()
  if(NOT EXISTS "${NEXVYN_IMGUI_VULKAN_BACKENDS}/imgui_impl_vulkan.cpp")
    message(FATAL_ERROR "Set NEXVYN_IMGUI_VULKAN_BACKENDS to the backends directory of Dear ImGui 1.91.5.")
  endif()

  set(_glslang "$ENV{NEXVYN_GLSLANG}")
  if(NOT _glslang)
    find_program(_glslang NAMES glslangValidator glslang)
  endif()
  set(_spirv_val "$ENV{NEXVYN_SPIRV_VAL}")
  if(NOT _spirv_val)
    find_program(_spirv_val NAMES spirv-val)
  endif()
  if(NOT _glslang OR NOT _spirv_val)
    message(FATAL_ERROR "vk_model needs host glslangValidator and spirv-val (NEXVYN_GLSLANG, NEXVYN_SPIRV_VAL).")
  endif()
  set(_python "$ENV{NEXVYN_PYTHON}")
  if(NOT _python)
    find_program(_python NAMES python3 python REQUIRED)
  endif()

  # Reuses vk_canary's compiler script: compile, validate (vulkan1.3) and embed both stages as C arrays.
  set(_shader_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")
  set(_shader_header "${_shader_dir}/vk_model_shaders.h")
  set(_compile "${NEXVYN_KIT}/examples/vk_canary/tools/compile_shaders.py")
  add_custom_command(
    OUTPUT "${_shader_header}"
    COMMAND "${_python}" "${_compile}"
            --vert "${CMAKE_CURRENT_SOURCE_DIR}/shaders/model.vert"
            --frag "${CMAKE_CURRENT_SOURCE_DIR}/shaders/model.frag"
            --out "${_shader_header}" --glslang "${_glslang}" --spirv-val "${_spirv_val}"
    DEPENDS shaders/model.vert shaders/model.frag "${_compile}"
    COMMENT "Compiling and validating vk_model SPIR-V shaders"
    VERBATIM)
  add_custom_target(vk_model_shaders DEPENDS "${_shader_header}")

  set(IMGUI_DIR "${NEXVYN_KIT}/sysroot/vendor/imgui")
  set(IMGUI_SRC ${IMGUI_DIR}/imgui.cpp ${IMGUI_DIR}/imgui_draw.cpp ${IMGUI_DIR}/imgui_tables.cpp
                ${IMGUI_DIR}/imgui_widgets.cpp "${NEXVYN_IMGUI_VULKAN_BACKENDS}/imgui_impl_vulkan.cpp")
  set_source_files_properties(${IMGUI_SRC} PROPERTIES COMPILE_OPTIONS "-w")
  # The backend loads its functions through nxn_vk_proc (nxn_imgui_vulkan_init); the app itself links the shims.
  set_source_files_properties("${NEXVYN_IMGUI_VULKAN_BACKENDS}/imgui_impl_vulkan.cpp"
                              PROPERTIES COMPILE_DEFINITIONS IMGUI_IMPL_VULKAN_NO_PROTOTYPES)
  list(APPEND VK_MODEL_SOURCES ${IMGUI_SRC})
endif()

nexvyn_add_windowed(${PROJECT_NAME} SOURCES ${VK_MODEL_SOURCES})

if(NEXVYN_VK_SHIMS)
  add_dependencies(${PROJECT_NAME}_objects vk_model_shaders)
  target_include_directories(${PROJECT_NAME}_objects PRIVATE
    "${NEXVYN_SYSROOT}/include" "${_shader_dir}" "${IMGUI_DIR}" "${NEXVYN_IMGUI_VULKAN_BACKENDS}")
  target_compile_definitions(${PROJECT_NAME}_objects PRIVATE NEXVYN_VK_SHIMS=1 IMGUI_DISABLE_DEFAULT_SHELL_FUNCTIONS)
  target_compile_options(${PROJECT_NAME}_objects PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions>")
endif()
