import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:orchid/api/monitoring/restart_manager.dart';
import 'package:orchid/api/orchid_api_mock.dart';
import 'package:orchid/api/orchid_budget_api.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/orchid_account.dart';
import 'package:orchid/api/orchid_eth/v1/orchid_eth_v1.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/orchid_types.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orchid/api/pricing/orchid_pricing.dart';
import 'package:orchid/common/app_sizes.dart';
import 'package:orchid/common/screen_orientation.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/pages/account_manager/account_detail_poller.dart';
import 'package:orchid/pages/account_manager/account_manager_page.dart';
import 'package:orchid/pages/circuit/circuit_page.dart';
import 'package:orchid/pages/circuit/model/circuit.dart';
import 'package:orchid/pages/circuit/model/circuit_hop.dart';
import 'package:orchid/pages/connect/manage_accounts_card.dart';
import 'package:orchid/orchid/orchid_action_button.dart';
import 'package:orchid/orchid/orchid_logo.dart';
import 'package:orchid/pages/circuit/model/orchid_hop.dart';
import 'package:orchid/common/app_dialogs.dart';
import 'package:orchid/common/formatting.dart';
import 'package:orchid/api/orchid_api.dart';
import 'package:orchid/pages/connect/release.dart';
import 'package:orchid/pages/connect/welcome_panel.dart';
import 'package:orchid/util/streams.dart';
import 'package:orchid/util/units.dart';

import 'connect_status_panel.dart';

/// The main page containing the connect button.
class ConnectPage extends StatefulWidget {
  ConnectPage({Key key}) : super(key: key);

  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage>
    with TickerProviderStateMixin {
  List<StreamSubscription> _subs = [];

  // Current routing state reflected by the page, driving color and animation.
  OrchidVPNRoutingState _routingState = OrchidVPNRoutingState.VPNNotConnected;

  // Lower level vpn state, used in the detail status message.
  OrchidVPNExtensionState _vpnState = OrchidVPNExtensionState.Invalid;

  // Routing and monitoring status
  bool _routingEnabled;
  bool _monitoringEnabled;
  bool _restarting = false;

  Timer _updateStatsTimer;

  // Circuit configuration
  Circuit _circuit;

  // Key that increments on changes to the circuit
  int _circuitKey = 0;

  bool get _hasCircuit {
    return _circuit != null;
  }

  int get _circuitHops {
    return _circuit?.hops?.length ?? 0;
  }

  bool get _circuitHasHops{
    return _circuitHops > 0;
  }

  // _hasCircuit here waits for the UI to load
  bool get _showWelcomePane => _hasCircuit && !_circuitHasHops;

  // The hop selected on the manage accounts card
  int _selectedIndex = 0;

  // The selected hop or null
  CircuitHop get _selectedHop {
    if (!_circuitHasHops) { return null; }
    return _circuit.hops[_selectedIndex];
  }

  // The account associated with the selected hop or null.
  Account get _selectedAccount {
    if (_selectedHop != null && _selectedHop is OrchidHop) {
      return (_selectedHop as OrchidHop).account;
    } else {
      return null;
    }
  }

  AccountDetailPoller _selectedAccountPoller;

  // V1 status data
  USD _bandwidthPrice;
  double _bandwidthAvailableGB; // GB

  NeonOrchidLogoController _logoController;

  @override
  void initState() {
    super.initState();
    ScreenOrientation.reset();

    _initListeners();

    _updateStatsTimer = Timer.periodic(Duration(seconds: 30), _updateStats);
    _updateStats(null);

    _releaseVersionCheck();

    _logoController = NeonOrchidLogoController(vsync: this);

    // Note: There seems to be a bug in SharedPreferences where accessing it
    // Note: too early during startup causes problems for this setup.
    Future.delayed(Duration(seconds: 0)).then((_) {
      MockOrchidAPI.checkStartupCommandArgs(context);
    });
  }

  /// Update alerts, badging, and status information.
  Future<void> _updateStats(timer) async {
    try {
      await _selectedAccountPoller?.refresh();
    } catch (err) {
      log("eror refreshing account details: $err");
    }

    // update bandwidth price
    try {
      _bandwidthPrice = await OrchidEthereumV1.getBandwidthPrice();
    } catch (err) {
      log("error getting bandwidth price: $err");
    }

    // update bandwidth available estimate
    if (_selectedAccount != null) {
      try {
        LotteryPot pot = await _selectedAccount.getLotteryPot();
        var tokenToUsd = await OrchidPricing().tokenToUsdRate(pot.balance.type);
        _bandwidthAvailableGB =
            pot.balance.floatValue * tokenToUsd / _bandwidthPrice.value;
      } catch (err) {
        _bandwidthAvailableGB = null;
        log("error calculating bandwidth available: $err");
      }
    } else {
      _bandwidthAvailableGB = null;
    }
  }

  // Note: We should migrate to a provider context
  /// Listen for changes in Orchid network status.
  void _initListeners() async {
    log('Connect Page: Init listeners...');

    // Monitor connection status
    OrchidAPI().vpnRoutingStatus.listen((OrchidVPNRoutingState state) {
      log('[connect page] Connection status changed: $state');
      _routingStateChanged(state);
    }).dispose(_subs);

    // Monitor circuit changes
    OrchidAPI().circuitConfigurationChanged.listen((value) {
      _circuitConfigurationChanged();
      _updateStats(null); // refresh alert status
    }).dispose(_subs);

    // Monitor routing preference
    UserPreferences().routingEnabled.stream().listen((enabled) {
      log("routing enabled changed: $enabled");
      setState(() {
        _routingEnabled = enabled;
      });
    }).dispose(_subs);

    // Monitor traffic monitoring preference
    UserPreferences().monitoringEnabled.stream().listen((enabled) {
      setState(() {
        _monitoringEnabled = enabled;
      });
    }).dispose(_subs);

    // Monitor automated restarts
    OrchidRestartManager().restarting.stream.listen((value) {
      setState(() {
        _restarting = value;
      });
    }).dispose(_subs);

    // Monitor low level vpn changes for the status line.
    OrchidAPI().vpnExtensionStatus.stream.listen((value) {
      setState(() {
        _vpnState = value;
      });
    }).dispose(_subs);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (!isReallyShort)
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
                animation: _logoController.listenable,
                builder: (BuildContext context, Widget child) {
                  return NeonOrchidLogo(
                    light: _logoController.value,
                    offset: _logoController.offset,
                  );
                  // return NeonOrchidLogo(light: 1.0);
                }),
          ),

        // The page content including the button title, button, and route info when connected.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            // padding: EdgeInsets.zero,
            child: _buildPageContent(),
          ),
        ),

        // The connect button
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: _showWelcomePane ? 80 : 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 300, child: _buildStatusMessageLine()),
                pady(20),
                _buildConnectButton(),
              ],
            ),
          ),
        ),

        // The welcome panel
        if (_showWelcomePane)
          Container(
            alignment: Alignment.bottomCenter,
            child: WelcomePanel(),
          )
      ],
    );
  }

  Widget _buildConnectButton() {
    String text;
    if (_restarting) {
      text = s.restarting;
    } else {
      switch (_routingState) {
        case OrchidVPNRoutingState.VPNDisconnecting:
          text = s.disconnecting;
          break;
        case OrchidVPNRoutingState.VPNConnecting:
          text = s.starting; // vpn is starting
          break;
        case OrchidVPNRoutingState.VPNConnected:
          text = s.connecting; // orchid is connecting
          break;
        case OrchidVPNRoutingState.VPNNotConnected:
          text = s.connect;
          break;
        case OrchidVPNRoutingState.OrchidConnected:
          text = s.disconnect;
      }
    }
    bool buttonEnabled =
        ( // Enabled when there is a circuit (or overridden for traffic monitoring)
                _hasCircuit ||
                    // TODO:
                    // Enabled if we are already connected (corner case of changed config while connected).
                    _routingState == OrchidVPNRoutingState.VPNConnecting ||
                    _routingState == OrchidVPNRoutingState.VPNConnected ||
                    _routingState == OrchidVPNRoutingState.OrchidConnected) &&
            !_restarting;

    return OrchidActionButton(
      enabled: buttonEnabled,
      text: text.toUpperCase(),
      onPressed: _onConnectButtonPressed,
    );
  }

  /// The page content including the button title, button, and route info when connected.
  Widget _buildPageContent() {
    return Column(
      children: <Widget>[
        if (!isReallyShort) Spacer(flex: isShort ? 2 : 3),
        _buildManageAccountsCard(),
        pady(24),
        _buildStatusPanel(),
        Spacer(flex: 2),
        if (_showWelcomePane) Spacer(flex: 1)
      ],
    );
  }

  Widget _buildManageAccountsCard() {
    return ManageAccountsCard(
      key: Key(_circuitKey.toString()),
      circuit: _circuit,
      minHeight: isShort,
      onSelectIndex: (index) {
        setState(() {
          log("XXX: selected index = $index");
          _selectedIndex = index;
          _selectedAccountChanged(_selectedAccount);
        });
      },
      onManageAccountsPressed: () async {
        log("XXX: manage accounts pressed, selectedAccount = $_selectedAccount");
        Navigator.push(context,
            MaterialPageRoute(builder: (BuildContext context) {
          return AccountManagerPage(openToAccount: _selectedAccount);
        }));
        _updateStats(null);
      },
    );
  }

  // only shows for v1
  Widget _buildStatusPanel() {
    return ConnectStatusPanel(
      key: Key(_selectedAccount?.identityUid ?? ""),
      minHeight: isShort,
      bandwidthPrice: _bandwidthPrice,
      circuitHops: _circuitHops,
      bandwidthAvailableGB: _bandwidthAvailableGB,
    );
  }

  Widget _buildStatusMessageLine() {
    String message;

    // The status message generally follows the routing state
    switch (_routingState) {
      case OrchidVPNRoutingState.VPNDisconnecting:
        message = s.orchidDisconnecting;
        break;
      case OrchidVPNRoutingState.VPNConnecting:
        message = s.orchidConnecting;
        break;
      case OrchidVPNRoutingState.VPNNotConnected:
        // Routing not connected, show vpn state if needed
        switch (_vpnState) {
          case OrchidVPNExtensionState.Invalid:
          case OrchidVPNExtensionState.NotConnected:
            message = _hasCircuit ? s.pushToConnect : '';
            break;
          case OrchidVPNExtensionState.Connecting:
            message = s.startingVpn;
            break;
          case OrchidVPNExtensionState.Disconnecting:
            message = s.disconnectingVpn;
            break;
          case OrchidVPNExtensionState.Connected:
            if (!_routingEnabled) {
              message = s.orchidAnalyzingTraffic;
            } else {
              message = s.vpnConnectedButNotRouting;
            }
            break;
        }
        break;
      case OrchidVPNRoutingState.VPNConnected:
        message = s.pausingAllTraffic + '\n' + s.queryingEthereumForARandom;
        break;
      case OrchidVPNRoutingState.OrchidConnected:
        if (_monitoringEnabled) {
          message = s.orchidRunningAndAnalyzing;
        } else {
          message = s.orchidIsRunning;
        }
    }

    if (_restarting) {
      message = s.restarting + ': ' + message;
    }

    return Text(
      message,
      style: OrchidText.caption,
      textAlign: TextAlign.center,
    );
  }

  /// Called upon a change to Orchid connection state
  void _routingStateChanged(OrchidVPNRoutingState state) async {
    _routingState = state;

    switch (state) {
      case OrchidVPNRoutingState.VPNNotConnected:
        _logoController.off();
        break;
      case OrchidVPNRoutingState.VPNConnecting:
      case OrchidVPNRoutingState.VPNConnected:
      case OrchidVPNRoutingState.VPNDisconnecting:
        _logoController.pulseHalf();
        break;
      case OrchidVPNRoutingState.OrchidConnected:
        _logoController.full();
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Toggle the current connection state
  void _onConnectButtonPressed() async {
    UserPreferences().routingEnabled.set(!_routingEnabled);
  }

  /// Do first launch and per-release activities.
  Future<void> _releaseVersionCheck() async {
    var version = await UserPreferences().releaseVersion.get();

    await _doMigrationActivities();

    log("first launch check.");
    if (version.isFirstLaunch) {
      await _doFirstLaunchActivities();
    }

    log("new version check.");
    var releaseNotes =
        const bool.fromEnvironment('release_notes', defaultValue: null);
    if (releaseNotes ?? version.isOlderThan(Release.current)) {
      await _doNewReleaseActivities();
    }

    await UserPreferences().releaseVersion.set(Release.current);
  }

  Future<void> _doFirstLaunchActivities() async {
    await _createFirstIdentity();
    // await _migrate1HopToActiveAccount();
    await _migrateActiveAccountTo1Hop();
  }

  Future<void> _doMigrationActivities() async {
    await _migrateActiveAccountTo1Hop();
  }

  // If this is an existing user with no multi-hop circuit and an active
  // account, migrate it to a 1-hop config.
  Future<void> _migrateActiveAccountTo1Hop() async {
    var circuit = await UserPreferences().getCircuit();
    if (circuit.hops.isEmpty) {
      var activeAccount = await Account.activeAccountLegacy;
      if (activeAccount != null) {
        log("migration: User has no hops and a legacy active account: migrating.");
        // Create a one hop circuit from this account
        var orchidHop = OrchidHop.fromAccount(activeAccount);
        var circuit = Circuit([orchidHop]);
        CircuitUtils.saveCircuit(circuit);

        // Clear the legacy active accounts (one time migration)
        UserPreferences().activeAccounts.set([]);
      }
    }
  }

  Future<void> _createFirstIdentity() async {
    log("first launch: Do first launch activities.");
    // If this is a new user with no identities create one.
    var identities = await UserPreferences().keys.get();
    if (identities.isEmpty) {
      log("first launch: Creating default identity");
      var key = StoredEthereumKey.generate();
      await UserPreferences().addKey(key);
      // Select it
      // AccountStore().setActiveIdentity(key);
    }
  }

  Future<void> _doNewReleaseActivities() async {
    log("new release: Do new release activities.");
    return AppDialogs.showAppDialog(
      context: context,
      title: await Release.title(context),
      body: Release.message(context),
    );
  }

  Future _circuitConfigurationChanged() async {
    log("xxx: connect page: circuit configuration changed");
    var prefs = UserPreferences();
    _circuit = await prefs.getCircuit();
    _selectedIndex = 0;

    // Update the card... need a key
    _circuitKey += 1;
    
    _selectedAccountChanged(_selectedAccount);
    setState(() {});
  }

  // TODO: remove this selected account logic and simplify update stats
  // The selected account has changed, update or remove the account detail poller.
  // Manage the selected account (the account that is forefront on the manage accoutns
  // card).
  Future _selectedAccountChanged(Account account) async {
    _selectedAccountPoller?.cancel();
    if (account != null) {
      _selectedAccountPoller = AccountDetailPoller(account: account);
      try {
        await _selectedAccountPoller.refresh(); // poll once
      } catch (err) {
        log("Error: $err");
      }
    } else {
      _selectedAccountPoller = null;
    }
    await _updateStats(null);
    setState(() {});
  }

  bool get isShort {
    return AppSize(context).shorterThan(Size(0, 700));
  }

  bool get isReallyShort {
    return AppSize(context).shorterThan(Size(0, 590));
  }

  @override
  void dispose() {
    super.dispose();
    ScreenOrientation.reset();
    _updateStatsTimer.cancel();
    _subs.dispose();
  }

  S get s {
    return S.of(context);
  }
}
