# Nexvyn native SDK: project helpers. Include after project():
#   include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
#   add_executable(mygame main.cpp)
#   nexvyn_add_nro(mygame TITLE "My Game" AUTHOR "Me" VERSION "1.0.0" ICON icon.jpg)
#
# nexvyn_add_nro() produces <target>.nro next to the build (title, author, version go to the NACP; ICON is a 256x256
# JPEG, the libnx default icon is used when omitted; ROMFS is an optional folder packed into the nro).
#
# Shared libraries (.nxvlib, optional; static linking stays the default, docs/NATIVE_KIT.en.md "Shared libraries"):
#   nexvyn_add_lib(greet NAME greet VERSION 1.2.0 SOURCES lib/greet.c [LINK <extra objects / static libs>])
#     -> <build>/greet.nxvlib: -fPIC objects linked as an AArch64 shared object with undefined symbols left open
#        (the app that loads it provides libc, libstdc++ and libnx), text relocations refused (-z text), the identity
#        NXN_LIB_ABI_GEN + NAME + VERSION in its ".nxvlib" section.
#   nexvyn_export_symbols(myapp LIBS greet [other.nxvlib ...])
#     -> the app exports its symbols (--export-dynamic, SysV hash) and links in every libc / libnx / libstdc++
#        function the listed libraries import, so nxn_lib_open() / dlopen() can bind them.

# Windowed apps (.nxvmod, the primary mode: the app runs in a Nexvyn OS window; docs/NATIVE_KIT.en.md "Windowed apps"):
#   nexvyn_add_windowed(mygame SOURCES src/main.c [NAME mygame] [LINK <extra objects / PIC static libs>] [LINK_OPTIONS ...])
#     -> <build>/mygame.nxvmod: -fPIC objects linked as an AArch64 shared object (-Bsymbolic, no text relocations), the
#        identity of libnexvyn_window.a, the C++ runtime and libgcc from the toolchain's pic multilib. nxn_* and the C
#        library come from Nexvyn OS's host import set at run time.
#   cmake -DNEXVYN_WINDOWED=ON (`nxv-native build --windowed`): every nexvyn_add_nro() target is built as a windowed
#     module instead, from the same sources, so one project builds both ways.

include_guard(GLOBAL)

# Kit defaults for Release (Debug stays -O0-style, no LTO): -O2 + LTO. devkitPro's rule overrides set the Release flags after
# the toolchain file runs, so they are completed here, after project(). -ffat-lto-objects keeps every object usable by a plain
# `ar` / `ld` (static libraries of the project, prebuilt kit archives): LTO never breaks a link that works without it.
# CPU: the toolchain passes -march=armv8-a+crc+crypto -mtune=cortex-a57 (the meaning of -mcpu=cortex-a57; NEON is part of
# armv8-a); -mcpu is not added because gcc warns when both are given. NEXVYN_LTO=OFF turns LTO off (cmake -DNEXVYN_LTO=OFF).
option(NEXVYN_LTO "Link-time optimisation in Release builds" ON)
if(NEXVYN_LTO)
  foreach(_lang C CXX)
    if(NOT CMAKE_${_lang}_FLAGS_RELEASE MATCHES "-flto")
      set(CMAKE_${_lang}_FLAGS_RELEASE "${CMAKE_${_lang}_FLAGS_RELEASE} -flto=auto -ffat-lto-objects")
    endif()
  endforeach()
  if(NOT CMAKE_EXE_LINKER_FLAGS_RELEASE MATCHES "-flto")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} -flto=auto")
  endif()
endif()

option(NEXVYN_WINDOWED "Build nexvyn_add_nro() targets as windowed apps (.nxvmod) instead of .nro" OFF)

# Directory of this file, captured at include time: inside a function CMAKE_CURRENT_LIST_DIR is the caller's folder.
set(_NEXVYN_NATIVE_TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}")

if(NEXVYN_WINDOWED)
  # Windowed builds look for SDL2 in <sysroot>/windowed first: the SDL2 with the Nexvyn OS drivers (nxn display, audio,
  # input; sysroot/build.py sdl2-nexvyn). The stub glesv2.pc / egl.pc (lib/windowed-pkgconfig) say "no library to link":
  # the GL entry points are in libnexvyn_window.a and reach the app's own GL context. Everything an app links must be
  # -fPIC: its static libraries too.
  set(_nexvyn_win_pc "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/../lib/windowed-pkgconfig")
  get_filename_component(_nexvyn_win_pc "${_nexvyn_win_pc}" ABSOLUTE)
  set(_nexvyn_win_sdl "")
  if(NEXVYN_SYSROOT AND IS_DIRECTORY "${NEXVYN_SYSROOT}/windowed")
    set(_nexvyn_win_sdl "${NEXVYN_SYSROOT}/windowed")
    list(PREPEND CMAKE_PREFIX_PATH "${_nexvyn_win_sdl}")
    list(PREPEND CMAKE_FIND_ROOT_PATH "${_nexvyn_win_sdl}")
  endif()
  # devkitPro's aarch64-none-elf-pkg-config resets PKG_CONFIG_PATH and sees the portlibs only: a windowed build uses the
  # shell's pkg-config with its own search list (windowed SDL2, the stub .pc files, the overlay, then the portlibs).
  find_program(_nexvyn_pkg_config NAMES pkg-config)
  if(_nexvyn_pkg_config)
    set(_nexvyn_pc_dirs "${_nexvyn_win_pc}")
    if(_nexvyn_win_sdl)
      list(PREPEND _nexvyn_pc_dirs "${_nexvyn_win_sdl}/lib/pkgconfig")
    endif()
    if(NEXVYN_SYSROOT AND IS_DIRECTORY "${NEXVYN_SYSROOT}/lib/pkgconfig")
      list(APPEND _nexvyn_pc_dirs "${NEXVYN_SYSROOT}/lib/pkgconfig")
    endif()
    list(APPEND _nexvyn_pc_dirs "$ENV{DEVKITPRO}/portlibs/switch/lib/pkgconfig")
    string(REPLACE ";" ":" _nexvyn_pc_dirs "${_nexvyn_pc_dirs}")
    set(PKG_CONFIG_EXECUTABLE "${_nexvyn_pkg_config}" CACHE FILEPATH "pkg-config of a windowed build" FORCE)
    set(PKG_CONFIG_ARGN "--static" CACHE STRING "pkg-config arguments of a windowed build" FORCE)
    set(ENV{PKG_CONFIG_LIBDIR} "${_nexvyn_pc_dirs}")
    set(ENV{PKG_CONFIG_PATH} "")
  endif()
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  # headers of the portlibs (GLES3/gl3.h, zlib.h, ...): the pc files of the windowed prefix do not name them
  include_directories(AFTER SYSTEM "$ENV{DEVKITPRO}/portlibs/switch/include")
endif()

# The static libraries a windowed app links: the project's own static library targets and archives under
# <sysroot>/windowed (SDL2). System archives (libc, libm, libpthread, libnx, EGL, GLES: the host serves them) are left out.
function(_nexvyn_windowed_link_items out deps_out)
  set(_res "")
  set(_deps "")
  set(_seen "")
  set(_todo ${ARGN})
  while(_todo)
    list(POP_FRONT _todo _l)
    if("${_l}" IN_LIST _seen)
      continue()
    endif()
    list(APPEND _seen "${_l}")
    if(_l MATCHES [[^\$<LINK_ONLY:(.*)>$]])
      list(APPEND _todo "${CMAKE_MATCH_1}")
    elseif(_l MATCHES [[^\$<]])
      continue()
    elseif(TARGET "${_l}")
      get_target_property(_type "${_l}" TYPE)
      get_target_property(_imported "${_l}" IMPORTED)
      if(_type STREQUAL "STATIC_LIBRARY" AND NOT _imported)
        list(APPEND _res "$<TARGET_FILE:${_l}>")
        list(APPEND _deps "${_l}")
        get_target_property(_sub "${_l}" LINK_LIBRARIES)
      else()
        # an imported static library of <sysroot>/windowed (CMake config packages: SDL2_mixer::SDL2_mixer-static ...)
        if(_type STREQUAL "STATIC_LIBRARY")
          foreach(_prop IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE IMPORTED_LOCATION_NOCONFIG)
            get_target_property(_loc "${_l}" ${_prop})
            if(_loc AND _nexvyn_win_sdl AND _loc MATCHES "/windowed/" AND NOT "${_loc}" IN_LIST _res)
              list(APPEND _res "${_loc}")
            endif()
          endforeach()
        endif()
        get_target_property(_sub "${_l}" INTERFACE_LINK_LIBRARIES)
      endif()
      if(_sub)
        list(APPEND _todo ${_sub})
      endif()
    elseif(_l MATCHES [[\.a$]] AND _nexvyn_win_sdl AND _l MATCHES "/windowed/")
      list(APPEND _res "${_l}")
    endif()
  endwhile()
  set(${out} "${_res}" PARENT_SCOPE)
  set(${deps_out} "${_deps}" PARENT_SCOPE)
endfunction()

# Switch this on once <nexvyn/nexvyn_native.h> and libnexvyn_native.a exist (Nexvyn ABI, native SDK 1.0).
#   cmake -DNEXVYN_ABI=ON ...
option(NEXVYN_ABI "Link the Nexvyn native ABI (nexvyn/nexvyn_native.h, -lnexvyn_native)" OFF)

function(nexvyn_add_nro target)
  cmake_parse_arguments(A "" "TITLE;AUTHOR;VERSION;ICON;ROMFS" "" ${ARGN})
  if(NEXVYN_WINDOWED)
    # the same sources as a windowed module; the .nro target is left out of the build
    get_target_property(_srcs ${target} SOURCES)
    get_target_property(_dir ${target} SOURCE_DIR)
    set(_abs "")
    foreach(_s IN LISTS _srcs)
      if(IS_ABSOLUTE "${_s}")
        list(APPEND _abs "${_s}")
      else()
        list(APPEND _abs "${_dir}/${_s}")
      endif()
    endforeach()
    # what nexvyn_use_compat() recorded (compat/cmake/nexvyn-compat.cmake): the PIC archive, --wrap flags, force-include
    get_target_property(_wlink ${target} NXN_WIN_LINK)
    get_target_property(_wlopt ${target} NXN_WIN_LINK_OPTIONS)
    get_target_property(_wcopt ${target} NXN_WIN_COMPILE_OPTIONS)
    foreach(_v _wlink _wlopt _wcopt)
      if(NOT ${_v})
        set(${_v} "")
      endif()
    endforeach()
    # the app's own static libraries and <sysroot>/windowed archives (SDL2)
    get_target_property(_tlibs ${target} LINK_LIBRARIES)
    set(_wlibs "")
    set(_wdeps "")
    if(_tlibs)
      _nexvyn_windowed_link_items(_wlibs _wdeps ${_tlibs})
    endif()
    nexvyn_add_windowed(${target}_windowed NAME ${target} SOURCES ${_abs} LINK ${_wlibs} ${_wlink} LINK_OPTIONS ${_wlopt})
    if(_wdeps)
      add_dependencies(${target}_windowed ${_wdeps})
    endif()
    if(_wcopt)
      target_compile_options(${target}_windowed_objects PRIVATE ${_wcopt})
    endif()
    if(_tlibs)
      # include directories and defines of what the app links (an OBJECT library takes the usage requirements only)
      target_link_libraries(${target}_windowed_objects PRIVATE ${_tlibs})
    endif()
    get_target_property(_inc ${target} INCLUDE_DIRECTORIES)
    if(_inc)
      target_include_directories(${target}_windowed_objects PRIVATE ${_inc})
    endif()
    get_target_property(_defs ${target} COMPILE_DEFINITIONS)
    if(_defs)
      target_compile_definitions(${target}_windowed_objects PRIVATE ${_defs})
    endif()
    set_target_properties(${target} PROPERTIES EXCLUDE_FROM_ALL ON)
    return()
  endif()
  if(NOT A_TITLE)
    set(A_TITLE "${target}")
  endif()
  if(NOT A_AUTHOR)
    set(A_AUTHOR "Unknown")
  endif()
  if(NOT A_VERSION)
    set(A_VERSION "1.0.0")
  endif()

  if(NEXVYN_ABI)
    if(NOT DEFINED NEXVYN_KIT_ROOT)
      if(DEFINED NEXVYN_KIT)
        get_filename_component(NEXVYN_KIT_ROOT "${NEXVYN_KIT}" ABSOLUTE)
      else()
        get_filename_component(NEXVYN_KIT_ROOT "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/.." ABSOLUTE)
      endif()
    endif()
    target_include_directories(${target} PRIVATE "${NEXVYN_KIT_ROOT}/include")
    target_link_directories(${target} PRIVATE "${NEXVYN_KIT_ROOT}/lib")
    target_link_libraries(${target} PRIVATE nexvyn_native)
    target_compile_definitions(${target} PRIVATE NEXVYN_ABI=1)
  endif()

  set(_nacp "${CMAKE_CURRENT_BINARY_DIR}/${target}.nacp")
  nx_generate_nacp(OUTPUT "${_nacp}" NAME "${A_TITLE}" AUTHOR "${A_AUTHOR}" VERSION "${A_VERSION}")
  set(_args NACP "${_nacp}")
  if(A_ICON)
    list(APPEND _args ICON "${A_ICON}")
  endif()
  if(A_ROMFS)
    list(APPEND _args ROMFS "${A_ROMFS}")
  endif()
  nx_create_nro(${target} ${_args})
endfunction()

function(_nexvyn_kit_root out)
  if(DEFINED NEXVYN_KIT)
    get_filename_component(_root "${NEXVYN_KIT}" ABSOLUTE)
  else()
    get_filename_component(_root "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/.." ABSOLUTE)
  endif()
  set(${out} "${_root}" PARENT_SCOPE)
endfunction()

# A shared library (.nxvlib): see the top of this file.
# crtend.o of the toolchain: the zero word that ends .eh_frame, so Nexvyn OS can hand the module's exception frames to
# its own unwinder (nxw_rt_eh_frames in libnexvyn_window.a / nxvlib_support.c). It must be the last object of the link.
function(_nexvyn_crtend out)
  if(NOT NEXVYN_CRTEND)
    execute_process(COMMAND "${CMAKE_C_COMPILER}" -fPIC -print-file-name=crtend.o
                    OUTPUT_VARIABLE _f OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT EXISTS "${_f}")
      message(FATAL_ERROR "crtend.o of the toolchain not found (${CMAKE_C_COMPILER} -print-file-name=crtend.o)")
    endif()
    set(NEXVYN_CRTEND "${_f}" CACHE INTERNAL "crtend.o of the toolchain")
  endif()
  set(${out} "${NEXVYN_CRTEND}" PARENT_SCOPE)
endfunction()

function(nexvyn_add_lib target)
  cmake_parse_arguments(A "" "NAME;VERSION" "SOURCES;LINK" ${ARGN})
  if(NOT A_NAME)
    set(A_NAME "${target}")
  endif()
  if(NOT A_VERSION)
    set(A_VERSION "1.0.0")
  endif()
  if(NOT A_NAME MATCHES "^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
    message(FATAL_ERROR "nexvyn_add_lib: NAME '${A_NAME}' may hold letters, digits and _ . + - only")
  endif()
  if(NOT A_VERSION MATCHES "^[0-9]+(\\.[0-9]+(\\.[0-9]+)?)?(-[0-9A-Za-z.-]+)?$")
    message(FATAL_ERROR "nexvyn_add_lib: VERSION '${A_VERSION}' is not a semver (major.minor.patch)")
  endif()
  if(NOT A_SOURCES)
    message(FATAL_ERROR "nexvyn_add_lib: no SOURCES")
  endif()
  _nexvyn_kit_root(_kit)
  add_library(${target}_objects OBJECT ${A_SOURCES} "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/nxvlib_support.c")
  set_target_properties(${target}_objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
  # -fPIC after the toolchain's -fPIE. thread_local: -mtls-dialect=trad -ftls-model=global-dynamic, over devkitPro's
  # local-exec (__tls_get_addr; with -mtp=soft devkitA64's gcc
  # miscompiles the default TLSDESC dialect). Nexvyn OS serves it in windowed apps (setting native.windowedTls).
  target_compile_options(${target}_objects PRIVATE -fPIC -mtls-dialect=trad -ftls-model=global-dynamic)
  _nexvyn_crtend(_crtend)
  target_include_directories(${target}_objects PRIVATE "${_kit}/include")
  target_compile_definitions(${target}_objects PRIVATE "NXVLIB_NAME=\"${A_NAME}\"" "NXVLIB_VERSION=\"${A_VERSION}\"")
  set(_out "${CMAKE_CURRENT_BINARY_DIR}/${A_NAME}.nxvlib")
  _nexvyn_split_debug_cmds(_split "${_out}")
  add_custom_command(OUTPUT "${_out}"
    COMMAND "${CMAKE_C_COMPILER}" -shared -nostartfiles -nostdlib -g -march=armv8-a+crc+crypto -mtune=cortex-a57
            -mtp=soft -mtls-dialect=trad -fPIC -Wl,-z,now -Wl,-z,text -Wl,-z,max-page-size=0x1000 -Wl,--hash-style=sysv
            -Wl,--gc-sections -Wl,--build-id=sha1 -Wl,--undefined=nxvlib_identity "-Wl,-soname,${A_NAME}.nxvlib"
            "$<TARGET_OBJECTS:${target}_objects>" ${A_LINK} -lgcc "${_crtend}"
            -o "${_out}"
    ${_split}
    DEPENDS ${target}_objects "$<TARGET_OBJECTS:${target}_objects>"
    COMMENT "Linking shared library ${A_NAME}.nxvlib"
    COMMAND_EXPAND_LISTS VERBATIM)
  add_custom_target(${target} ALL DEPENDS "${_out}")
  set_target_properties(${target} PROPERTIES NXVLIB_FILE "${_out}" NXVLIB_NAME "${A_NAME}" NXVLIB_VERSION "${A_VERSION}")
endfunction()

# The app side of shared libraries: see the top of this file.
function(nexvyn_export_symbols target)
  cmake_parse_arguments(A "" "" "LIBS" ${ARGN})
  target_link_options(${target} PRIVATE "LINKER:--export-dynamic" "LINKER:--hash-style=sysv")
  set(_files "")
  foreach(_l IN LISTS A_LIBS)
    if(TARGET ${_l})
      get_target_property(_f ${_l} NXVLIB_FILE)
      if(NOT _f)
        message(FATAL_ERROR "nexvyn_export_symbols: ${_l} is not a nexvyn_add_lib() target")
      endif()
      add_dependencies(${target} ${_l})
    else()
      get_filename_component(_f "${_l}" ABSOLUTE)
    endif()
    list(APPEND _files "${_f}")
  endforeach()
  if(NOT _files)
    return()
  endif()
  set(_nm "${DKP_NM}")
  if(NOT _nm)
    set(_nm "${CMAKE_NM}")
  endif()
  set(_ld "${CMAKE_CURRENT_BINARY_DIR}/${target}_nxvlib_imports.ld")
  string(REPLACE ";" "|" _joined "${_files}")
  add_custom_command(OUTPUT "${_ld}"
    COMMAND "${CMAKE_COMMAND}" "-DNM=${_nm}" "-DLIBS=${_joined}" "-DOUT=${_ld}"
            -P "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/nxvlib_imports.cmake"
    DEPENDS ${_files} "${_NEXVYN_NATIVE_TOOLCHAIN_DIR}/nxvlib_imports.cmake"
    COMMENT "Collecting the imports of ${target}'s shared libraries"
    VERBATIM)
  add_custom_target(${target}_nxvlib_imports DEPENDS "${_ld}")
  foreach(_l IN LISTS A_LIBS)
    if(TARGET ${_l})
      add_dependencies(${target}_nxvlib_imports ${_l})
    endif()
  endforeach()
  add_dependencies(${target} ${target}_nxvlib_imports)
  # an implicit linker script (EXTERN(...)): pulls the archive members that define the imports
  target_link_options(${target} PRIVATE "${_ld}")
  set_property(TARGET ${target} APPEND PROPERTY LINK_DEPENDS "${_ld}")
endfunction()

# Split debug information (crash symbols): a build-id is linked in, the debug info moves to <module>.debug next to the
# module (build folder only, never packaged) and is stripped from the module. `nxv-native symbolize` reads the .debug file
# and matches it to a crash report by the build-id. The module keeps its symbol table and behaves the same.
function(_nexvyn_split_debug_cmds out_var file)
  get_filename_component(_cc_dir "${CMAKE_C_COMPILER}" DIRECTORY)
  find_program(_nexvyn_objcopy NAMES aarch64-none-elf-objcopy objcopy HINTS "${_cc_dir}" NO_DEFAULT_PATH)
  if(NOT _nexvyn_objcopy)
    find_program(_nexvyn_objcopy NAMES aarch64-none-elf-objcopy objcopy)
  endif()
  if(_nexvyn_objcopy)
    set(${out_var}
        COMMAND "${_nexvyn_objcopy}" --only-keep-debug "${file}" "${file}.debug"
        COMMAND "${_nexvyn_objcopy}" --strip-debug "${file}"
        PARENT_SCOPE)
  else()
    set(${out_var} "" PARENT_SCOPE)
  endif()
endfunction()

# A windowed app (.nxvmod): see the top of this file.
function(nexvyn_add_windowed target)
  cmake_parse_arguments(A "" "NAME" "SOURCES;LINK;LINK_OPTIONS" ${ARGN})
  if(NOT A_NAME)
    set(A_NAME "${target}")
  endif()
  if(NOT A_SOURCES)
    message(FATAL_ERROR "nexvyn_add_windowed: no SOURCES")
  endif()
  _nexvyn_kit_root(_kit)
  add_library(${target}_objects OBJECT ${A_SOURCES})
  set_target_properties(${target}_objects PROPERTIES POSITION_INDEPENDENT_CODE ON)
  # -fPIC after the toolchain's -fPIE; thread_local through __tls_get_addr (-mtls-dialect=trad, see nexvyn_add_lib)
  target_compile_options(${target}_objects PRIVATE -fPIC -mtls-dialect=trad -ftls-model=global-dynamic)
  _nexvyn_crtend(_crtend)
  target_include_directories(${target}_objects PRIVATE "${_kit}/include")
  target_compile_definitions(${target}_objects PRIVATE NEXVYN_ABI=1 NEXVYN_WINDOWED=1)
  # the archives sit in a group: static libraries may need each other in any order (SDL2_mixer needs SDL2)
  set(_out "${CMAKE_CURRENT_BINARY_DIR}/${A_NAME}.nxvmod")
  set(_link_deps "")  # archives / objects given with LINK: a rebuilt one relinks the module
  foreach(_l IN LISTS A_LINK)
    if(IS_ABSOLUTE "${_l}" AND EXISTS "${_l}")
      list(APPEND _link_deps "${_l}")
    endif()
  endforeach()
  # Release objects carry LTO bytecode next to the machine code (nexvyn-switch.cmake): the module link optimises across them
  set(_nexvyn_lto_link "")
  if(NEXVYN_LTO)
    set(_nexvyn_lto_link "$<$<CONFIG:Release>:-flto=auto>")
  endif()
  _nexvyn_split_debug_cmds(_split "${_out}")
  # LTO generates the code at link time: the frame pointer option has to be on the link line too
  set(_nexvyn_fp_link "")
  if(NEXVYN_FRAME_POINTER)
    set(_nexvyn_fp_link "-fno-omit-frame-pointer" "-mno-omit-leaf-frame-pointer")
  endif()
  add_custom_command(OUTPUT "${_out}"
    COMMAND "${CMAKE_CXX_COMPILER}" -shared -nostartfiles -nostdlib -g -march=armv8-a+crc+crypto -mtune=cortex-a57
            -mtp=soft -mtls-dialect=trad -fPIC -Wl,-Bsymbolic -Wl,-z,now -Wl,-z,text -Wl,-z,max-page-size=0x1000 -Wl,--hash-style=sysv
            -Wl,--gc-sections -Wl,--build-id=sha1 -Wl,--undefined=nxnwin_identity ${_nexvyn_lto_link} ${_nexvyn_fp_link}
            "$<TARGET_OBJECTS:${target}_objects>" -Wl,--start-group ${A_LINK} -Wl,--end-group ${A_LINK_OPTIONS} "-L${_kit}/lib" -lnexvyn_window -lstdc++ -lsupc++ -lgcc
            "${_crtend}" -o "${_out}"
    ${_split}
    DEPENDS ${target}_objects "$<TARGET_OBJECTS:${target}_objects>" "${_kit}/lib/libnexvyn_window.a" ${_link_deps}
    COMMENT "Linking windowed app ${A_NAME}.nxvmod"
    COMMAND_EXPAND_LISTS VERBATIM)
  add_custom_target(${target} ALL DEPENDS "${_out}")
  set_target_properties(${target} PROPERTIES NXVMOD_FILE "${_out}")
endfunction()
