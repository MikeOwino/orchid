# Orchid - WebRTC P2P VPN Market (on Ethereum)
# Copyright (C) 2017-2020  The Orchid Authors

# Zero Clause BSD license {{{
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# }}}


cflags += -DHAVE_SA_LEN
cflags += -DHAVE_SCONN_LEN

cflags += -D__APPLE_USE_RFC_2292

lflags += -framework CoreFoundation
lflags += -framework Foundation

cflags += -DWEBRTC_POSIX
cflags += -DWEBRTC_MAC

source += $(pwd)/webrtc/rtc_base/mac_ifaddrs_converter.cc
source += $(pwd)/webrtc/rtc_base/system/cocoa_threading.mm

include $(pwd)/target-psx.mk
