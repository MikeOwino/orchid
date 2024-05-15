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


#ifndef ORCHID_STRUCTURED_HPP
#define ORCHID_STRUCTURED_HPP

#include "link.hpp"
#include "notation.hpp"

namespace orc {

class Structured :
    public Pump<Json::Value, Json::Value>,
    public BufferDrain,
    public Sunken<Pump<Buffer>>
{
  protected:
    void Land(const Buffer &data) override {
        return Pump::Land(Parse(data.str()));
    }

  public:
    Structured(Drain<Json::Value> &drain) :
        Pump(typeid(*this).name(), drain)
    {
    }

    task<void> Shut() noexcept override {
        co_await Sunken::Shut();
        co_await Pump::Shut();
    }

    task<void> Send(const Json::Value &data) override {
        co_return co_await Inner().Send(Strung(UnparseO(data)));
    }
};

}

#endif//ORCHID_STRUCTURED_HPP
