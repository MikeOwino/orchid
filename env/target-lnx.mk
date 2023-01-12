# Cycc/Cympile - Shared Build Scripts for Make
# Copyright (C) 2013-2020  Jay Freeman (saurik)

# Zero Clause BSD license {{{
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# }}}


pre := lib
dll := so
lib := a
exe := 

ifeq ($(libc),)
libc := gnu
endif

meson := linux

archs += i386
openssl/i386 := linux-x86
host/i386 := i386-linux-$(libc)
triple/i386 := i686-unknown-linux-$(libc)
meson/i386 := x86
bits/i386 := 32
centos/i386 := i686

archs += x86_64
openssl/x86_64 := linux-x86_64
host/x86_64 := x86_64-linux-$(libc)
triple/x86_64 := x86_64-unknown-linux-$(libc)
meson/x86_64 := x86_64
bits/x86_64 := 64
centos/x86_64 := x86_64

archs += arm64
openssl/arm64 := linux-aarch64
host/arm64 := aarch64-linux-$(libc)
triple/arm64 := aarch64-unknown-linux-$(libc)
meson/arm64 := aarch64
bits/arm64 := 64

archs += armhf
openssl/armhf := linux-armv4
host/armhf := arm-linux-$(libc)eabihf
triple/armhf := arm-unknown-linux-$(libc)eabihf
meson/armhf := arm
bits/armhf := 32

archs += mips
openssl/mips := linux-mips32
host/mips := mips-linux-$(libc)
triple/mips := mips-unknown-linux-$(libc)
meson/mips := mips
bits/mips := 32

ifeq ($(machine),)
machine := $(uname-m)
endif

include $(pwd)/target-elf.mk
lflags += -Wl,--hash-style=gnu

ifeq ($(filter crossndk,$(debug))$(uname-s),Linux)

define _
ranlib/$(1) := ranlib
ar/$(1) := ar
strip/$(1) := strip
windres/$(1) := false
endef
$(each)

cc := clang$(suffix)
cxx := clang++$(suffix)

include $(pwd)/target-cxx.mk

tidy := $(shell which clang-tidy 2>/dev/null)
ifeq ($(tidy)$(filter notidy,$(debug)),)
debug += notidy
endif

else

more := 
more += --gcc-toolchain=$(CURDIR)/$(output)/sysroot/usr
include $(pwd)/target-ndk.mk
include $(pwd)/target-cxx.mk

lflags += -lrt

define _
more/$(1) := 
ifneq ($(centos/$(1)),)
more/$(1) += --sysroot $(CURDIR)/$(output)/sysroot
else
more/$(1) += --sysroot $(CURDIR)/$(output)/sysroot/usr/$(host/$(1))
endif
more/$(1) += -B$(llvm)/$(subst -$(libc),-android,$(host/$(1)))/bin
more/$(1) += -target $(host/$(1))
ranlib/$(1) := $(llvm)/bin/llvm-ranlib
ar/$(1) := $(llvm)/bin/llvm-ar
strip/$(1) := $(llvm)/bin/$(1)-linux-android-strip
windres/$(1) := false
endef
$(each)

# XXX: v8 requires armv6k for the "yield" instruction
more/armhf += -march=armv6k -D__ARM_MAX_ARCH__=8

ifeq ($(distro),)
ifneq ($(centos/$(machine)),)
distro := centos6 $(machine) $(centos/$(machine))
else
distro := ubuntu bionic
endif
endif

# XXX: consider naming sysroot folder after distro
$(output)/sysroot: env/sys-$(word 1,$(distro)).sh env/setup-sys.sh
	$< $@ $(wordlist 2,$(words $(distro)),$(distro)) || { rm -rf $@; false; }

.PHONY: sysroot
sysroot: $(output)/sysroot

sysroot += $(output)/sysroot

endif

lflags += -ldl
lflags += -pthread
