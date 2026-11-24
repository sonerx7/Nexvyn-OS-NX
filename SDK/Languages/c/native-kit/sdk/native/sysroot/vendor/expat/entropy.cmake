# Only this recipe's C sources use the libnx entropy adapter.
include_directories("${CMAKE_CURRENT_LIST_DIR}")
add_compile_options("$<$<COMPILE_LANGUAGE:C>:-includeentropy.h>")
