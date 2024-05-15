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


#ifndef ORCHID_SPECIFIC_HPP
#define ORCHID_SPECIFIC_HPP

#include <pthread.h>

#include "error.hpp"

namespace orc {

class Specific {
  private:
    pthread_key_t key_;
    void *value_;

  public:
    Specific(pthread_key_t key, const void *value) :
        key_(key),
        value_(pthread_getspecific(key_))
    {
        orc_insist(pthread_setspecific(key_, value) == 0);
    }

    ~Specific() {
        orc_insist(pthread_setspecific(key_, value_) == 0);
    }
};

}

#endif//ORCHID_SPECIFIC_HPP
