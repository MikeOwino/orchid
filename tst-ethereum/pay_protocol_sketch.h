/* Orchid - WebRTC P2P VPN Market (on Ethereum)
 * Copyright (C) 2017-2019  The Orchid Authors
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



/*


Minutes = 60;
Hours   = 60*Minutes;
Days    = 24*Hours;
Weeks   = 7*Days;

struct Budget_PredExpW
{
	// budgeting params (input from UI)
	budget_edate_;   	     // target budget end date
	max_faceval_;            // maximum allowable faceval in OXT (user's hard variance limit)
	max_prepay_time_ = 10;   // max amount of time client will prepay (credit) to server for undelivered bandwidth, in seconds (client->server trust)

    // config hyperparams
	timer_sample_rate_ = 60; // frequency of calls to on_timer() (nothing special about 60s)

    // internal
    prepay_credit_;
	route_active_;                  // true when a connection/circuit is active
	exp_half_life   = 1*Weeks;      // 1 one week 50% smoothing period
	last_pay_date_;


    get_afford() {
        time_owed = (CurrentTime() - last_pay_date);
		allowed   = spendrate_ * (time_owed + prepay_credit_);
		return allowed;       
    }
    
    get_max_faceval() {
        return max_faceval_;
    }

    on_timer() {
    
        double ltime    = persist_load("ltime", CurrentTime()); // load variable from persistent disk/DB/config, default to CurrentTime()
        double wactive  = persist_load("wactive", 1.0);       

        // predict the fraction of time Orchid is active & connected (simple exp smoothing predictor) 
        double etime    = CurrentTime() - ltime;
        double decay    = exp(log(0.5) * etime/exp_half_life);        
        double cactive  = route_active_ ? 1.0 : 0.0;       
        wactive         = decay*wactive + (1-decay)*cactive;
        ltime           = CurrentTime();
        
        double pred_future_active_time = (budget_edate_ - CurrentTime()) * wactive;
		spendrate_      = get_OXT_balance() / (pred_future_active_time + 1*Days);

        persist_store("ltime",   ltime);
        persist_store("wactive", wactive);
    }

    Budget_PredExpW() {
        register_timer_func(&on_timer, timer_sample_rate_); // call on_timer() every {timer_sample_rate_} seconds
        route_active_ = false;
        on_timer(); // tick the timer once on startup to update for any time orchid was shutdown
    }
    
    on_connect()    { route_active = true;  last_pay_date_ = CurrentTime(); prepay_credit_ = max_prepay_time_; }
    on_disconnect() { route_active = false; }
    on_invoice()    { last_pay_date_ = CurrentTime(); prepay_credit_ = 0; }
};

struct Client
{
	// budgeting params (input from UI)
	target_overhead_ = 0.1;	// target transaction fee overhead  // move to server?

	// Internal
	last_pay_date_ = CurrentTime();
	
	budgetf_ = new Budget_PredExpW();
    
    
	// External functions
    	get_max_trans_cost();   // (oracle) get estimate of max reasonable current transaction fees
    	get_OXT_balance();  	// (RPC call, cached) external eth balance 
    	get_trust_bound();  	// max OXT amount client is willing to lend to server (can initially be a large constant)

	// user initiates connection to server (random selection picks server)
	on_connect(server) 	 { send("connect", server, ...);  budget_->on_connect(); }
    
    // callback when disconnected from route
	on_disconnect()     { budget_->on_disconnect(); }   

	on_invoice(bal_owed, trans_cost) { // server requests payment from client
		
		afford 	    	= budget_->get_afford();
		max_face_val	= budget_->get_max_faceval();
		//trust_bound 	= get_trust_bound();
		//exp_val     	= min(afford, bal_owed, trust_bound); // removed into budgeting
		exp_val     	= min(afford, bal_owed);
       	trans_cost  	= min(get_max_trans_cost(), trans_cost);
		face_val	    = trans_cost / target_overhead_;
		//face_val      = min(face_val, max_face_val);
		if (face_val > max_face_val) face_val = 0;  // hard constraint failure
		
		if (face_val > trans_cost) {
			win_prob    = exp_val / (face_val - trans_cost);
			win_prob	= max(min(win_prob, 1), 0); // todo: server may want a lower bound on win_prob for double-spend reasons
			send("upay", server_, payment{win_prob, face_val, ..} );
			budget_->on_invoice();
			// any book-keeping here
		}
		else {
			// handle payment error
		}
	}
};

struct Server
{
	// Server Hyperparams - from a config file or something
	bytes_per_upay_;  // desired inv frequency of micropayments, in bytes
	data_price_;	  // server's OXT/byte price
	targ_balance_;    // target min client balance before invoice sent
	min_balance_;     // min client balance to route packets (default 0)

	// Internal
	balances_;
    
	// External functions
	get_trans_cost();    // (oracle) get current transaction cost estimate
	is_winner(payment);  // offline check to see if ticket is a winner
    	
	// Protocol client message handlers
	on_connect(client);		    // client connection request
	on_upay(client, payment);	// upayment from client
    	
	// On packet data event handlers
	on_out_packets(src, data);	// inc data from client out to target
	on_in_packets(src, data);   // inc data from target out to client

	invoice_check(client) {
		if (balances[client] <= targ_balance_) {
		    billed_amt  = max(bytes_per_upay_ * data_price_, targ_balance_ - balances[client]);
		    send("invoice", client, billed_amt, get_trans_cost());
		}
	}

	// client connection request
	on_connect(client) {
		invoice_check(client);
		// connection established, stuff happens		
	}

	// todo: remove sync ethnode RPC calls with async
	check_payment(payment) { // validate the micropayment (does not verify it's a winner)
		if (RPC.balance(payment.sender).amount_ <     payment.faceVal)) return false;
		if (RPC.balance(payment.sender).escrow_ < 2 * payment.faceVal)) return false; // 2 is justin's magic number, and may change
	}
	
	// upayment from client
	on_upay(client, payment) { //  uses blocking external ethnode RPC calls
		if (check_payment(payment)) { // validate the micropayment
			trans_fee = get_trans_cost();
			balances_[client] += (payment.faceVal - trans_fee) * payment.winProb;
			if (is_winner(payment) { // now check to see if it's a winner, and redeem if so
				RPC.grab(payment, trans_fee);
			}
		}
	}
	
	bill_packet(data) {
		cost   = data.size_ * data_price_;
		balances[client] -= cost;
		invoice_check(client);
	}

	on_out_packets(client, data) {	// inc data from client out to target
		bill_packet(data);
		if (balances[client] > min_balance_) { send(client.target, data); }
	}

	on_in_packets(client, data) {   // inc data from target out to client
		bill_packet(data);
		if (balances[client] > min_balance_) { send(client, data); }
	}
};

