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


#include "protocol.hpp"

namespace orc {

const Socket Port_(0u, 5482);

void Scan(const Buffer &data, const std::function<void (const Buffer &)> &code) {
    Window window(data);
    while (!window.done()) {
        Number<uint16_t> length;
        // XXX: I need (already have?) a Prefix Buffer
        window.Take(length);
        code(window.Take(length.operator uint16_t()));
    }
}

}
