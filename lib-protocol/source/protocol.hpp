/* Orchid - WebRTC P2P VPN Market (on Ethereum)
 * Copyright (C) 2017-2020  The Orchid Authors
*/

/* GNU Affero General Public License, Version 3 {{{ */
/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */


#ifndef ORCHID_PROTOCOL_HPP
#define ORCHID_PROTOCOL_HPP

#include <functional>
#include <tuple>

#include "jsonrpc.hpp"
#include "socket.hpp"

namespace orc {

extern const Socket Port_;
typedef std::tuple<uint32_t, Bytes32> Header;

static const uint32_t Magic_(0xff0fce1d);
static const uint32_t Stamp_(0xee6d796e);

static const uint32_t Submit0_(0xfd90e312);
static const uint32_t Submit1_(0xf0ece7ca);

static const uint32_t Invoice0_(0x01959987);

void Scan(const Buffer &data, const std::function<void (const Buffer &)> &code);

template <typename... Args_>
auto Command(const Args_ &...args) {
    auto data(Tie(args...));
    return std::make_tuple(uint16_t(data.size()), data);
}

}

#endif//ORCHID_PROTOCOL_HPP
