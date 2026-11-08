# Nexvyn native SDK: the compatibility layer for plain Makefile projects (devkitPro style).
#
#   include <kit>/compat/compat.mk
#   CFLAGS   += $(NXC_CFLAGS)
#   CXXFLAGS += $(NXC_CFLAGS)
#   LDFLAGS  += $(NXC_LDFLAGS)
#   LIBS     := $(LIBS) $(NXC_LIBS_END)    # LAST on the line: the layer (and libnx behind it) must come after every
#                                          # library that calls a wrapped function (libEGL, SDL2 ...). A static library
#                                          # is searched once, so a library listed later cannot use the layer.
#                                          # (NXC_LIBS is only -lnexvyn_compat, for projects that place it themselves.)
#   # optional PC path handling: add compat/fsmap_on.c to the sources and
#   LDFLAGS  += $(NXC_FSMAP_LDFLAGS)
#   # optional compile time warnings for fork / exec / system ...:  CFLAGS += -DNXC_STRICT=1
#   # dlopen of .nxvlib libraries, when the app also links -lnexvyn_native:  LDFLAGS += $(NXC_DL_LDFLAGS)
#
# A windowed app (.nxvmod, -fPIC, linked with -shared): compile with $(NXC_CFLAGS) as above, link the objects with
#   $(NXC_WIN_LDFLAGS) $(NXC_WIN_LIBS)      (the archive goes after the objects, before -lnexvyn_window)
# and nothing else changes (docs/NATIVE_COMPAT.en.md "In a window"). The wrap list there already contains the file-call
# family of fsmap: a window has its own working directory, kept by the layer.
#
# Build the library once: make -C <kit>/compat   (builds lib/libnexvyn_compat.a and lib/libnexvyn_compat_pic.a)

NXC_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

NXC_WRAP_CORE  := $(shell cat "$(NXC_DIR)/wrap_core.txt")
NXC_WRAP_FSMAP := $(shell cat "$(NXC_DIR)/wrap_fsmap.txt")
NXC_WRAP_WIN   := $(shell grep -v '^\#' "$(NXC_DIR)/wrap_win.txt")

NXC_CFLAGS         := -I$(NXC_DIR)/include -DNXC_COMPAT=1 -include nexvyn/compat_posix.h
NXC_LDFLAGS        := -L$(NXC_DIR)/lib $(foreach s,$(NXC_WRAP_CORE),-Wl,--wrap=$(s))
NXC_LIBS           := -lnexvyn_compat
NXC_LIBS_END       := -Wl,--start-group -lnexvyn_compat -lnx -Wl,--end-group
# stat is in wrap_core.txt already; repeated so that NXC_FSMAP_LDFLAGS also works without NXC_LDFLAGS
NXC_FSMAP_LDFLAGS  := $(foreach s,$(NXC_WRAP_FSMAP) stat,-Wl,--wrap=$(s))
NXC_FSMAP_SRC      := $(NXC_DIR)/fsmap_on.c
# the layer references nxn_lib_* weakly; this pulls them out of libnexvyn_native.a
NXC_DL_LDFLAGS     := -Wl,--undefined=nxn_lib_open
# windowed apps: the -fPIC archive and every --wrap name (core + file family + runtime hooks + sockets)
NXC_WIN_LDFLAGS    := $(foreach s,$(NXC_WRAP_CORE) $(NXC_WRAP_FSMAP) $(NXC_WRAP_WIN),-Wl,--wrap=$(s))
NXC_WIN_LIBS       := $(NXC_DIR)/lib/libnexvyn_compat_pic.a
