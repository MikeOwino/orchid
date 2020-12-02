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


#ifndef ORCHID_NODE_HPP
#define ORCHID_NODE_HPP

#include <vector>

#include "egress.hpp"
#include "jsonrpc.hpp"
#include "locator.hpp"
#include "server.hpp"

namespace orc {

class Cashier;
class Croupier;

class Node final {
  private:
    const S<Origin> origin_;
    const S<Cashier> cashier_;
    const S<Croupier> croupier_;
    const S<Egress> egress_;
    const std::vector<std::string> ice_;

    struct Locked_ {
        std::map<std::string, W<Server>> servers_;
    }; Locked<Locked_> locked_;

  public:
    Node(S<Origin> origin, S<Cashier> cashier, S<Croupier> croupier, S<Egress> egress, std::vector<std::string> ice) :
        origin_(std::move(origin)),
        cashier_(std::move(cashier)),
        croupier_(std::move(croupier)),
        egress_(std::move(egress)),
        ice_(std::move(ice))
    {
    }

    S<Server> Find(const std::string &fingerprint) {
        const auto locked(locked_());
        auto &cache(locked->servers_[fingerprint]);
        if (auto server = cache.lock())
            return server;
        const auto server(Break<BufferSink<Server>>(cashier_, croupier_));
        Egress::Wire(egress_, *server);
        server->self_ = server;
        cache = server;
        return server;
    }

    void Run(const asio::ip::address &bind, uint16_t port, const std::string &key, const std::string &certificates, const std::string &params);
};

}

#endif//ORCHID_NODE_HPP
