# Nexvyn Native SDK - libnexvyn_native.a, the exclusive-mode implementation of the nxn_* ABI, and libnexvyn_window.a,
# the windowed-mode support object (NATIVE_KIT.md).
# Built with the pinned devkitPro toolchain (tools/toolchain.json):
#   make -C sdk/native/lib            -> sdk/native/lib/libnexvyn_native.a
#   make -C sdk/native/lib clean
# Apps link it before SDL2, EGL and libnx: -lnexvyn_native ... -lEGL -lglapi -ldrm_nouveau -lnx
# (nxv-native build --abi adds -I sdk/native/include -L sdk/native/lib -DNEXVYN_ABI).
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

HERE    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(DEVKITPRO)/devkitA64/base_tools

BUILD   := $(HERE)build
TARGET  := $(HERE)libnexvyn_native.a
SRCS    := $(wildcard $(HERE)src/*.c)
# the ELF loader core shared with Nexvyn OS (one implementation: sdk/native/loader/nxelf.c)
LOADER  := $(HERE)../loader
OBJS    := $(patsubst $(HERE)src/%.c,$(BUILD)/%.o,$(SRCS)) $(BUILD)/nxelf.o $(BUILD)/nxmem.o

ARCH    := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
CFLAGS  := -g -std=gnu11 -Wall -Wextra -Wno-unused-parameter -Wno-format-truncation -O2 -fno-omit-frame-pointer -ffunction-sections -fdata-sections $(ARCH) \
           -D__SWITCH__ -I$(HERE)../include -I$(LOADER) -I$(DEVKITPRO)/libnx/include -I$(DEVKITPRO)/portlibs/switch/include

# windowed mode (NATIVE_KIT.md 3.2): libnexvyn_window.a, -fPIC, linked into every .nxvmod. Nexvyn OS
# implements nxn_* for windowed apps; this archive only carries the module's identity and __dso_handle.
WIN_TARGET := $(HERE)libnexvyn_window.a
WIN_OBJS   := $(BUILD)/win/nxwin_support.o $(BUILD)/win/nxwin_gles.o $(BUILD)/win/nxwin_glcore.o
WIN_CFLAGS := $(subst -fPIE,-fPIC,$(CFLAGS))

.PHONY: all clean window
all: $(TARGET) $(WIN_TARGET)
window: $(WIN_TARGET)

$(BUILD)/win/%.o: $(HERE)win/%.c $(wildcard $(HERE)../include/nexvyn/*.h)
	@mkdir -p $(BUILD)/win
	$(CC) $(WIN_CFLAGS) -c $< -o $@

$(WIN_TARGET): $(WIN_OBJS)
	@rm -f $@
	$(AR) rcs $@ $^
	@echo built $(notdir $@)

$(BUILD)/%.o: $(HERE)src/%.c $(wildcard $(HERE)src/*.h) $(wildcard $(HERE)../include/nexvyn/*.h) $(LOADER)/nxelf.h $(LOADER)/nxmem.h
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/nxmem.o: $(LOADER)/nxmem.c $(LOADER)/nxmem.h
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/nxelf.o: $(LOADER)/nxelf.c $(LOADER)/nxelf.h
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	@rm -f $@
	$(AR) rcs $@ $^
	@echo built $(notdir $@)

clean:
	rm -rf $(BUILD) $(TARGET) $(WIN_TARGET)
