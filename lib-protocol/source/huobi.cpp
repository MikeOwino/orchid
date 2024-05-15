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


#include "base.hpp"
#include "huobi.hpp"
#include "locator.hpp"
#include "notation.hpp"

namespace orc {

task<Float> Huobi(Base &base, const std::string &pair, const Float &adjust) {
    const auto result(Parse((co_await base.Fetch("GET", {{"https", "api.huobi.pro", "443"}, "/market/trade?symbol=" + pair}, {}, {})).ok()).as_object());
    const auto status(Str(result.at("status")));
    if (false) {
    } else if (status == "ok") {
        const auto &ticks(result.at("tick").at("data").as_array());
        co_return Float(Num<double>(ticks.at(0).at("price"))) / adjust;
    } else if (status == "error") {
        const auto code(Str(result.at("err-code")));
        const auto message(Str(result.at("err-msg")));
        orc_throw(code << ": " << message);
    } else orc_assert(false);
}

}
