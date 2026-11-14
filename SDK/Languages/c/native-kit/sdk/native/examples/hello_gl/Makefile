# hello_gl - the smallest Nexvyn native app: GL, input, a tone, a file in its sandbox, crash tests. The same source builds
# for both modes. Needs sdk/native/lib/libnexvyn_native.a and libnexvyn_window.a (make -C sdk/native/lib).
#   make                     -> hello_gl.nro     (exclusive: its own .nro, Nexvyn OS steps aside)
#   make package             -> build/package/ (an unpacked .nxvapp bundle: app.json + hello_gl.nro + icon)
#   make windowed            -> hello_gl.nxvmod  (windowed, the primary mode: runs in a Nexvyn OS window)
#   make package-windowed    -> build/package-windowed/ (app.json "mode": "windowed" + hello_gl.nxvmod + icon)
.SUFFIXES:
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif
TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

TARGET		:=	hello_gl
BUILD		:=	build
SOURCES		:=	source
DATA		:=
INCLUDES	:=
APP_TITLE	:=	Hello GL
APP_AUTHOR	:=	Nexvyn OS
APP_VERSION	:=	1.0.0
NXN		:=	$(abspath $(TOPDIR)/../..)

ARCH	:=	-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE
CFLAGS	:=	-g -Wall -O2 -ffunction-sections $(ARCH) $(DEFINES) $(INCLUDE) -D__SWITCH__ -I$(NXN)/include
CXXFLAGS	:= $(CFLAGS) -fno-rtti -fno-exceptions
ASFLAGS	:=	-g $(ARCH)
LDFLAGS	=	-specs=$(DEVKITPRO)/libnx/switch.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)
# libnexvyn_native first, then GL / SDL2 (audio) / libnx
LIBS	:=	-L$(NXN)/lib -lnexvyn_native -lglad `$(PREFIX)pkg-config --libs --static sdl2` -lnx -lm
LIBDIRS	:=	$(PORTLIBS) $(LIBNX)

ifneq ($(BUILD),$(notdir $(CURDIR)))
export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)
export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir))
export DEPSDIR	:=	$(CURDIR)/$(BUILD)
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
export LD	:=	$(CC)
export OFILES	:=	$(CFILES:.c=.o)
export INCLUDE	:=	$(foreach dir,$(LIBDIRS),-I$(dir)/include) -I$(CURDIR)/$(BUILD)
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)
export APP_ICON	:=	$(LIBNX)/default_icon.jpg
export NROFLAGS	+=	--icon=$(APP_ICON) --nacp=$(CURDIR)/$(TARGET).nacp

# windowed: -fPIC objects linked as a shared object; nxn_* and the C library come from Nexvyn OS (its host import set),
# the module carries its identity (libnexvyn_window.a), glad and libgcc. NATIVE_KIT.md 3.2.
WIN_CFLAGS	:=	$(subst -fPIE,-fPIC,$(CFLAGS)) -I$(PORTLIBS)/include -I$(LIBNX)/include
WIN_LDFLAGS	:=	-shared -nostartfiles -nostdlib -g $(subst -fPIE,-fPIC,$(ARCH)) -Wl,-Bsymbolic -Wl,-z,now -Wl,-z,text 			-Wl,-z,max-page-size=0x1000 -Wl,--hash-style=sysv -Wl,--gc-sections -Wl,--undefined=nxnwin_identity
WIN_OBJS	:=	$(patsubst %.c,$(BUILD)/win/%.o,$(notdir $(wildcard $(SOURCES)/*.c)))

.PHONY: $(BUILD) clean all package windowed package-windowed
all: $(BUILD)
$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile
package: all
	@rm -rf $(BUILD)/package && mkdir -p $(BUILD)/package
	@cp package/app.json $(TARGET).nro $(BUILD)/package/
	@cp $(APP_ICON) $(BUILD)/package/icon.jpg
	@echo packaged $(BUILD)/package
windowed: $(TARGET).nxvmod
$(BUILD)/win/%.o: $(SOURCES)/%.c
	@mkdir -p $(BUILD)/win
	$(CC) $(WIN_CFLAGS) -c $< -o $@
$(TARGET).nxvmod: $(WIN_OBJS) $(NXN)/lib/libnexvyn_window.a
	$(CC) $(WIN_LDFLAGS) $(WIN_OBJS) -L$(NXN)/lib -lnexvyn_window -L$(PORTLIBS)/lib -lglad -lgcc -o $@
	@echo built $@
package-windowed: windowed
	@rm -rf $(BUILD)/package-windowed && mkdir -p $(BUILD)/package-windowed
	@cp package/app.windowed.json $(BUILD)/package-windowed/app.json
	@cp $(TARGET).nxvmod $(BUILD)/package-windowed/
	@cp $(APP_ICON) $(BUILD)/package-windowed/icon.jpg
	@echo packaged $(BUILD)/package-windowed
clean:
	@rm -fr $(BUILD) $(TARGET).nro $(TARGET).nacp $(TARGET).elf $(TARGET).nxvmod
else
.PHONY: all
DEPENDS	:=	$(OFILES:.o=.d)
all	:	$(OUTPUT).nro
$(OUTPUT).nro	:	$(OUTPUT).elf $(OUTPUT).nacp
$(OUTPUT).elf	:	$(OFILES) $(NXN)/lib/libnexvyn_native.a
-include $(DEPENDS)
endif
