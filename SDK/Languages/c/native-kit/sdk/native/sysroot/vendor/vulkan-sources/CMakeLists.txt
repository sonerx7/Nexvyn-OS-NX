# Source-only Vulkan dependencies: no compiler, linker or system loader needed.
cmake_minimum_required(VERSION 3.13)
project(nexvyn_vulkan_sources NONE)
get_filename_component(upstream "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

if(NEXVYN_SOURCE_RECIPE STREQUAL "vulkan-headers")
  if(NOT EXISTS "${upstream}/include/vulkan/vulkan_vi.h")
    message(FATAL_ERROR "Pinned Vulkan-Headers must include VK_NN_vi_surface")
  endif()
  install(DIRECTORY "${upstream}/include/" DESTINATION include)
elseif(NEXVYN_SOURCE_RECIPE STREQUAL "volk")
  # The console has no dynamic loader. Replace the <dlfcn.h> include of the pinned
  # volk.c with stubs that always fail, so volkInitialize() reports
  # VK_ERROR_INITIALIZATION_FAILED and apps use volkInitializeCustom only.
  file(READ "${upstream}/volk.c" volk_source)
  if(NOT volk_source MATCHES "#[ 	]*include <dlfcn.h>")
    message(FATAL_ERROR "Review pinned volk: <dlfcn.h> include not found")
  endif()
  if(NOT volk_source MATCHES "volkInitializeCustom")
    message(FATAL_ERROR "Review pinned volk: volkInitializeCustom missing")
  endif()
  string(REGEX REPLACE "#[ 	]*include <dlfcn.h>"
    "/* Nexvyn: custom lookup only; no system Vulkan loader. */
#define RTLD_NOW 0
#define RTLD_LOCAL 0
static void* dlopen(const char* n, int f) { (void)n; (void)f; return 0; }
static void* dlsym(void* m, const char* n) { (void)m; (void)n; return 0; }
static int dlclose(void* m) { (void)m; return 0; }"
    volk_source "${volk_source}")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/volk.c" "${volk_source}")
  install(FILES "${upstream}/volk.h" DESTINATION include)
  install(FILES "${upstream}/volk.h" "${CMAKE_CURRENT_BINARY_DIR}/volk.c"
    DESTINATION share/nexvyn/volk)
elseif(NEXVYN_SOURCE_RECIPE STREQUAL "vulkan-memory-allocator")
  install(FILES "${upstream}/include/vk_mem_alloc.h" DESTINATION include)
elseif(NEXVYN_SOURCE_RECIPE STREQUAL "spirv-reflect")
  install(FILES "${upstream}/spirv_reflect.h" DESTINATION include)
  install(DIRECTORY "${upstream}/include/spirv" DESTINATION include)
  install(FILES "${upstream}/spirv_reflect.h" "${upstream}/spirv_reflect.c"
    DESTINATION share/nexvyn/spirv-reflect)
  install(DIRECTORY "${upstream}/include/" DESTINATION share/nexvyn/spirv-reflect/include)
else()
  message(FATAL_ERROR "Unknown source recipe: ${NEXVYN_SOURCE_RECIPE}")
endif()
