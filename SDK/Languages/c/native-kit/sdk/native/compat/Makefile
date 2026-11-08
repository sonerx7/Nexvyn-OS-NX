# Nexvyn Native SDK - libnexvyn_compat.a, the optional POSIX / PC compatibility layer (docs/NATIVE_COMPAT.en.md).
# Built with the pinned devkitPro toolchain (tools/toolchain.json):
#   make -C sdk/native/compat            -> sdk/native/compat/lib/libnexvyn_compat.a
#   make -C sdk/native/compat clean
# Apps link it before libnx: -lnexvyn_compat ... -lnx, plus the --wrap flags of compat.mk (CMake: nexvyn_use_compat()).
# Windowed apps (.nxvmod, in-process) link lib/libnexvyn_compat_pic.a instead: the same sources built -fPIC with
# -DNXC_WINDOWED=1 (docs/NATIVE_COMPAT.en.md "In a window"); libnx and the C library come from Nexvyn OS's import set.
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

HERE    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(DEVKITPRO)/devkitA64/base_tools

BUILD   := $(HERE)build
TARGET  := $(HERE)lib/libnexvyn_compat.a
PIC_BUILD  := $(HERE)build_pic
PIC_TARGET := $(HERE)lib/libnexvyn_compat_pic.a
CSRCS   := $(wildcard $(HERE)src/*.c)
SSRCS   := $(wildcard $(HERE)src/*.S)
OBJS    := $(patsubst $(HERE)src/%.c,$(BUILD)/%.o,$(CSRCS)) $(patsubst $(HERE)src/%.S,$(BUILD)/%.o,$(SSRCS))

PIC_OBJS := $(patsubst $(HERE)src/%.c,$(PIC_BUILD)/%.o,$(CSRCS)) $(patsubst $(HERE)src/%.S,$(PIC_BUILD)/%.o,$(SSRCS))             $(PIC_BUILD)/nxc_win.o

ARCH    := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
INC     := -I$(HERE)include -I$(HERE)../include -I$(DEVKITPRO)/libnx/include
CFLAGS  := -g -std=gnu11 -Wall -Wextra -Wno-unused-parameter -O2 -ffunction-sections -fdata-sections $(ARCH) \
           -D__SWITCH__ -DNXC_BUILDING $(INC)
ASFLAGS := -g $(ARCH) -x assembler-with-cpp $(INC)

.PHONY: all clean
all: $(TARGET) $(PIC_TARGET)

DEPS := $(wildcard $(HERE)src/*.h) $(wildcard $(HERE)include/nexvyn/*.h) $(wildcard $(HERE)include/sys/*.h) \
        $(wildcard $(HERE)include/*.h)

$(BUILD)/%.o: $(HERE)src/%.c $(DEPS)
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/%.o: $(HERE)src/%.S $(DEPS)
	@mkdir -p $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

PIC_CFLAGS  := $(subst -fPIE,-fPIC,$(CFLAGS)) -DNXC_WINDOWED=1 -I$(HERE)src
PIC_ASFLAGS := $(subst -fPIE,-fPIC,$(ASFLAGS)) -DNXC_WINDOWED=1

$(PIC_BUILD)/%.o: $(HERE)src/%.c $(DEPS)
	@mkdir -p $(PIC_BUILD)
	$(CC) $(PIC_CFLAGS) -c $< -o $@

$(PIC_BUILD)/%.o: $(HERE)src/%.S $(DEPS)
	@mkdir -p $(PIC_BUILD)
	$(CC) $(PIC_ASFLAGS) -c $< -o $@

$(PIC_BUILD)/nxc_win.o: $(HERE)win/nxc_win.c $(DEPS)
	@mkdir -p $(PIC_BUILD)
	$(CC) $(PIC_CFLAGS) -c $< -o $@

$(PIC_TARGET): $(PIC_OBJS)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(AR) rcs $@ $^
	@echo built $(notdir $@)

$(TARGET): $(OBJS)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(AR) rcs $@ $^
	@echo built $(notdir $@)

clean:
	rm -rf $(BUILD) $(PIC_BUILD) $(HERE)lib
