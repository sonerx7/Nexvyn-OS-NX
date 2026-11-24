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
# implements the host imports. This archive carries the module identity, runtime support and kit shims.
WIN_TARGET := $(HERE)libnexvyn_window.a
WIN_OBJS   := $(BUILD)/win/nxwin_support.o $(BUILD)/win/nxwin_gles.o $(BUILD)/win/nxwin_glcore.o
WIN_OBJS   += $(BUILD)/win/nxn_thread_hint.o
ifeq ($(NEXVYN_LTO),1)
# base_tools supplies gcc-ar. Fat objects also carry machine code for non-GCC links.
CFLAGS += -flto=auto -ffat-lto-objects
endif
WIN_CFLAGS := $(subst -fPIE,-fPIC,$(CFLAGS))

# Optional link-time Vulkan entry shims (N5-F.2, tools/gen_vk_shim.py). The default archive omits them.
NEXVYN_VK_SHIMS ?= 0
WIN_VK_MODE := 0
ifeq ($(NEXVYN_VK_SHIMS),1)
WIN_VK_MODE := 1
NEXVYN_SYSROOT ?= $(abspath $(HERE)../../../build/native-sysroot)
NEXVYN_VK_INCLUDE ?= $(NEXVYN_SYSROOT)/include
WIN_OBJS += $(BUILD)/win/nxwin_vk.o
$(BUILD)/win/nxwin_vk.o: WIN_CFLAGS += -I$(NEXVYN_VK_INCLUDE)
endif
WIN_CONFIG := $(BUILD)/win/.vk-shims-$(WIN_VK_MODE)

.PHONY: all clean window
all: $(TARGET) $(WIN_TARGET)
window: $(WIN_TARGET)

$(BUILD)/win/%.o: $(HERE)win/%.c $(wildcard $(HERE)../include/nexvyn/*.h)
	@mkdir -p $(BUILD)/win
	$(CC) $(WIN_CFLAGS) -c $< -o $@

$(WIN_CONFIG):
	@mkdir -p $(dir $@)
	@rm -f $(BUILD)/win/.vk-shims-0 $(BUILD)/win/.vk-shims-1
	@touch $@

$(BUILD)/win/nxn_thread_hint.o: $(HERE)src/nxn_thread_hint.c $(wildcard $(HERE)../include/nexvyn/*.h)
	@mkdir -p $(BUILD)/win
	$(CC) $(WIN_CFLAGS) -DNEXVYN_WINDOWED=1 -c $< -o $@

$(WIN_TARGET): $(WIN_OBJS) $(WIN_CONFIG)
	@rm -f $@
	$(AR) rcs $@ $(WIN_OBJS)
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
	$(AR) rcs $@ $(OBJS)
	@echo built $(notdir $@)

ifneq ($(filter 1,$(NEXVYN_LTO))$(wildcard $(BUILD)/.nexvyn-lto),)
LTO_CONFIG := $(BUILD)/.nexvyn-lto
$(shell mkdir -p $(BUILD) && printf '%s\n' '$(if $(filter 1,$(NEXVYN_LTO)),1,0)' > $(LTO_CONFIG).tmp && \
	(cmp -s $(LTO_CONFIG).tmp $(LTO_CONFIG) && rm -f $(LTO_CONFIG).tmp || mv -f $(LTO_CONFIG).tmp $(LTO_CONFIG)))
ifneq ($(.SHELLSTATUS),0)
$(error Could not update $(LTO_CONFIG))
endif
$(OBJS) $(WIN_OBJS) $(TARGET) $(WIN_TARGET): $(LTO_CONFIG)
endif

clean:
	rm -rf $(BUILD) $(TARGET) $(WIN_TARGET)
