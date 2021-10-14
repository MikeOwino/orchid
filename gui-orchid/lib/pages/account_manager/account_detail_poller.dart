import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:orchid/api/orchid_budget_api.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/orchid_eth.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_market_v0.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_eth_v0.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_contract_v0.dart';
import 'package:orchid/api/orchid_eth/orchid_account.dart';

abstract class AccountDetail {
  Account get account;

  // The resolved signer address. Null until details are polled.
  EthereumAddress signerAddress;

  // The funder from the account
  EthereumAddress get funder {
    return account.funder;
  }

  // The lotter pot.  Null until polled
  LotteryPot get lotteryPot;

  // The market conditions. Null until polled
  MarketConditions get marketConditions;

  // The market alert flag.  False until polled
  bool get showMarketStatsAlert;

  // The transactions.  Null until polled
  List<OrchidUpdateTransactionV0> get transactions;
}

class AccountDetailPoller extends ChangeNotifier implements AccountDetail {
  final Account account;

  final Duration pollingPeriod;

  // The resolved signer address (non-async). Null until details are polled.
  EthereumAddress signerAddress;

  EthereumAddress get funder {
    return account.funder;
  }

  AccountDetailPoller({
    @required this.account,
    this.pollingPeriod = const Duration(seconds: 15),
  });

  Timer _balanceTimer;
  bool _balancePollInProgress = false;
  DateTime _lotteryPotLastUpdate;

  // Account Detail
  LotteryPot lotteryPot; // initially null
  MarketConditions marketConditions;
  bool showMarketStatsAlert = false;

  // TODO:
  List<OrchidUpdateTransactionV0> transactions;

  OrchidEthereum get eth {
    return OrchidEthereum(account.chain);
  }

  /// Start periodic polling
  Future<void> startPolling() async {
    _balanceTimer = Timer.periodic(pollingPeriod, (_) {
      _pollBalanceAndAccountDetails();
    });
    return _pollBalanceAndAccountDetails(); // kick one off immediately
  }

  /// Load data once
  Future<void> refresh() async {
    return _pollBalanceAndAccountDetails();
  }

  Future<void> _pollBalanceAndAccountDetails() async {
    if (signerAddress == null) {
      signerAddress = await account.signerAddress;
    }

    //log("polling account details: signer = $resolvedSigner, funder = $funder");
    if (_balancePollInProgress) {
      return;
    }
    _balancePollInProgress = true;
    try {
      // Fetch the pot balance
      LotteryPot _pot;
      try {
        //log("Detail poller fetch pot, eth=$eth, funder=$funder, signer=$resolvedSigner");
        _pot = await eth
            .getLotteryPot(funder, signerAddress)
            .timeout(Duration(seconds: 30));
      } catch (err) {
        log('Error fetching lottery pot 1: $err');
        return;
      }
      lotteryPot = _pot;
      _lotteryPotLastUpdate = DateTime.now();

      MarketConditions _marketConditions;
      try {
        _marketConditions =
            await eth.getMarketConditions(_pot).timeout(Duration(seconds: 60));
      } catch (err, stack) {
        log('Error fetching market conditions: $err\n$stack');
        //return;
      }
      marketConditions = _marketConditions;

      List<OrchidUpdateTransactionV0> _transactions;
      try {
        if (account.version == 0) {
          _transactions = await OrchidEthereumV0()
              .getUpdateTransactions(funder: funder, signer: signerAddress);
        } else {
          // _transactions = await OrchidEthereumV1()
          //     .getUpdateTransactions(funder: funder, signer: resolvedSigner);
        }
      } catch (err) {
        log('Error fetching account update transactions: $err');
      }
      transactions = _transactions;

      showMarketStatsAlert = (await eth.getMarketConditions(_pot)).efficiency <
          MarketConditions.minEfficiency;

      this.notifyListeners();
    } catch (err, stack) {
      log("Can't fetch balance: $err\n$stack");

      // Allow a stale balance for a period of time.
      if (_lotteryPotLastUpdate != null &&
          _lotteryPotLastUpdate.difference(DateTime.now()) >
              Duration(hours: 1)) {
        lotteryPot = null; // no balance available
        notifyListeners();
      }
    } finally {
      _balancePollInProgress = false;
    }
  }

  void cancel() {
    _balanceTimer?.cancel();
  }

  void dispose() {
    cancel();
    super.dispose();
  }
}
