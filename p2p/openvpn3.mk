# Orchid - WebRTC P2P VPN Market (on Ethereum)
# Copyright (C) 2017-2020  The Orchid Authors

# Zero Clause BSD license {{{
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# }}}


source += $(wildcard $(pwd)/lz4/lib/*.c)
cflags += -I$(pwd)/lz4/lib

cflags += -DUSE_ASIO
cflags += -DUSE_ASIO_THREADLOCAL
cflags += -DHAVE_LZ4
cflags += -DUSE_OPENSSL
cflags += -DOPENVPN_FORCE_TUN_NULL
cflags += -DUSE_TUN_BUILDER

source += $(wildcard $(pwd)/openvpn3/client/*.cpp)

cflags += -I$(pwd)/openvpn3
cflags += -I$(pwd)/openvpn3/client

cflags += -DOPENVPN_EXTERNAL_TRANSPORT_FACTORY
cflags += -DOPENVPN_EXTERNAL_TUN_FACTORY

# XXX: this is unfortunate
cflags/$(pwd)/ovpncli.mm += -Wno-deprecated-enum-enum-conversion
cflags/$(pwd)/openvpn3/ += -Wno-deprecated-enum-enum-conversion

ifeq ($(target),win)
cflags/$(pwd)/openvpn3/ += -Wno-missing-braces
cflags/$(pwd)/openvpn3/ += -Wno-pointer-bool-conversion
cflags/$(pwd)/openvpn3/ += -Wno-return-type
cflags/$(pwd)/openvpn3/ += -UUNICODE
cflags += -I$(pwd)/tap-windows6/src
endif
