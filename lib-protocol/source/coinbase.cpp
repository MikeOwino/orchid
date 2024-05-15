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
#include "pricing.hpp"

namespace orc {

task<Float> Coinbase(Base &base, const std::string &pair, const Float &adjust) {
    const auto response(co_await base.Fetch("GET", {{"https", "api.coinbase.com", "443"}, "/v2/prices/" + pair + "/spot"}, {}, {}));
    const auto result(Parse(response.body()).as_object());
    if (response.result() == http::status::ok) {
        const auto &data(result.at("data").as_object());
        co_return Float(Str(data.at("amount"))) / adjust;
    } else {
        const auto &errors(result.at("errors").as_array());
        orc_assert(errors.size() == 1);
        const auto &error(errors[0].as_object());
        const auto id(Str(error.at("id")));
        const auto message(Str(error.at("message")));
        orc_throw(response.result() << "/" << id << ": " << message);
    }
}

}
