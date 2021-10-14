import 'dart:async';
import 'package:flutter/material.dart';
import 'package:orchid/api/configuration/orchid_user_config/orchid_user_config.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/v0/orchid_eth_v0.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/pages/circuit/circuit_page.dart';
import 'package:orchid/pages/circuit/hop_editor.dart';
import 'package:orchid/pages/circuit/model/circuit.dart';
import 'package:orchid/pages/circuit/model/circuit_hop.dart';
import 'package:orchid/pages/circuit/model/orchid_hop.dart';
import 'package:orchid/pages/circuit/orchid_hop_page.dart';
import 'package:orchid/common/app_dialogs.dart';
import 'package:orchid/common/formatting.dart';
import 'package:orchid/common/titled_page_base.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../common/app_colors.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key key}) : super(key: key);

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<UniqueHop> _recentlyDeleted = [];
  List<OrphanedKeyAccount> _orphanedPacAccounts = [];

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    _recentlyDeleted = await _getRecentlyDeletedHops();
    setState(() {});
    _findOrphanedPACs();
  }

  @override
  Widget build(BuildContext context) {
    return TitledPage(
      title: s.deletedHops,
      child: SafeArea(child: buildPage(context)),
    );
  }

  Widget buildPage(BuildContext context) {
    List<Widget> list = [];
    if (_recentlyDeleted.isEmpty && _orphanedPacAccounts.isEmpty) {
      list.add(Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Text(
          s.noRecentlyDeletedHops,
          textAlign: TextAlign.center,
          style: OrchidText.body2,
        ),
      ));
    } else {
      list.add(pady(16));
      list.add(_buildInstructions());
      list.add(pady(32));
      list.addAll((_recentlyDeleted ?? []).map((hop) {
        return Center(child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildInactiveHopTile(hop),
        ));
      }).toList());
      if (_orphanedPacAccounts.isNotEmpty)
        list.add(Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 24),
          child: Text(s.deletedPacs),
        )));
      list.addAll((_orphanedPacAccounts ?? []).map((oa) {
        return Center(child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildOrphanedAccountHopTile(oa),
        ));
      }).toList());
    }
    return ListView(children: list);
  }

  /*
  Widget titleTile(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
      child: Text(
        text,
        style: TextStyle(fontSize: 20),
      ),
    );
  }
   */

  Dismissible _buildInactiveHopTile(UniqueHop uniqueHop) {
    return Dismissible(
      key: Key(uniqueHop.key.toString()),
      background: CircuitPageState.buildDismissableBackground(context),
      confirmDismiss: _confirmDeleteHop,
      onDismissed: (direction) {
        _deleteHop(uniqueHop);
      },
      child: _buildHopTile(uniqueHop, activeHop: false),
    );
  }

  Dismissible _buildOrphanedAccountHopTile(OrphanedKeyAccount account) {
    OrchidHop hop = OrchidHop.v0(
        funder: account.funder,
        curator: account.curator,
        keyRef: account.keyRef);
    UniqueHop uniqueHop =
        UniqueHop(hop: hop, key: account.keyRef.keyUid.hashCode);
    return Dismissible(
      key: Key(account.keyRef.toString()),
      background: CircuitPageState.buildDismissableBackground(context),
      confirmDismiss: _confirmDeleteHop,
      onDismissed: (direction) {
        _deleteOrphanedAcount(account);
      },
      child: _buildHopTile(uniqueHop, activeHop: false),
    );
  }

  void _deleteOrphanedAcount(OrphanedKeyAccount account) {
    log("account: delete orphaned account: ${account.keyRef}");
    UserPreferences().removeKey(account.keyRef);
    _findOrphanedPACs();
  }

  Widget _buildHopTile(UniqueHop uniqueHop, {bool activeHop = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: CircuitPageState.buildHopTile(
          context: context,
          onTap: () {
            _viewHop(uniqueHop);
          },
          uniqueHop: uniqueHop,
          bgColor: activeHop
              ? AppColors.purple_3.withOpacity(0.8)
              : Colors.grey[500],
          showAlertBadge: false),
    );
  }

  void _viewHop(UniqueHop uniqueHop, {bool animated = true}) async {
    EditableHop editableHop = EditableHop(uniqueHop);
    HopEditor editor = editableHop.editor();
    //  Turn off all editable features such as curation.
    if (editor is OrchidHopPage) {
      editor.disabled = true;
    }
    await editor.show(context, animated: animated);
  }

  Future<bool> _confirmDeleteHop(dismissDirection) async {
    var result = await AppDialogs.showConfirmationDialog(
      context: context,
      title: s.confirmDelete,
      bodyText: s.deletingThisHopWillRemoveItsConfiguredOrPurchasedAccount +
          "  " +
          s.ifYouPlanToReuseTheAccountLaterYouShould,
    );
    return result;
  }

  // Callback for swipe to delete
  void _deleteHop(UniqueHop uniqueHop) async {
    var index = _recentlyDeleted.indexOf(uniqueHop);
    setState(() {
      _recentlyDeleted.removeAt(index);
    });
    await UserPreferences().setRecentlyDeleted(
      Hops(_recentlyDeleted.map((h) {
        return h.hop;
      }).toList()),
    );

    // Deliberately leave orphaned keys for testing.
    bool orphanKeys = (await OrchidUserConfig().getUserConfigJS())
        .evalBoolDefault('orphanKeys', false);

    // Remove the key if it is no longer used.
    if (uniqueHop.hop is OrchidHop && !orphanKeys) {
      var hop = uniqueHop.hop as OrchidHop;

      // Determine if the key no longer referenced
      List<StoredEthereumKey> orphanedKeys = await getOrphanedKeys();
      if (orphanedKeys.map((e) => e.ref().keyUid).contains(hop.keyRef.keyUid) ) {
        await UserPreferences().removeKey(hop.keyRef);
      }
    }

    initStateAsync();
  }

  // e.g. recently deleted
  Future<List<UniqueHop>> _getRecentlyDeletedHops() async {
    var recentlyDeletedHops = await UserPreferences().getRecentlyDeleted();
    var keyBase = DateTime.now().millisecondsSinceEpoch;
    var hops = recentlyDeletedHops.hops.where((hop) {
      return hop is OrchidHop;
    }).toList();
    return UniqueHop.wrap(hops, keyBase);
  }

  S get s {
    return S.of(context);
  }

  void _findOrphanedPACs() async {
    _orphanedPacAccounts = [];

    List<StoredEthereumKey> orphanedKeys = await getOrphanedKeys();

    var curator = await UserPreferences().getDefaultCurator() ??
        OrchidHop.appDefaultCurator;

    // Determine which of these were PACs
    // TODO: for xdai this will be the seller contract address
    var orchidPacFunder =
        EthereumAddress.from('0x6dd46c5f9f19ab8790f6249322f58028a3185087');
    _orphanedPacAccounts = [];
    for (var key in orphanedKeys) {
      var signer = EthereumAddress.from(key.get().addressString);
      try {
        var pot = await OrchidEthereumV0.getLotteryPot(orchidPacFunder, signer);
        if (pot.balance.lteZero()) {
          log("account: zero balance found for keys: [$orchidPacFunder, $signer]");
          continue;
        }
        log("account: found orphaned PAC with non-zero balance: [$orchidPacFunder, $signer]");
        setState(() {
          _orphanedPacAccounts
              .add(OrphanedKeyAccount(orchidPacFunder, key.ref(), curator));
          log("_orphaned pac accounts len = ${_orphanedPacAccounts.length}");
        });
      } catch (err) {
        log("account: Error checking pot.");
      }
    }
    setState(() {});
  }

  Future<List<StoredEthereumKey>> getOrphanedKeys() async {
    // Get the active hop keys
    List<String> activeKeyUuids = await OrchidHop.getInUseKeyUids();

   // Get recently deleted hop list keys
    List<String> deletedKeyUuids = getRecentlyDeletedHopKeys();

    // Find the orphans
    List<StoredEthereumKey> allKeys = await UserPreferences().getKeys();
    List<StoredEthereumKey> orphanedKeys = allKeys
        .where((k) =>
            !activeKeyUuids.contains(k.uid) && !deletedKeyUuids.contains(k.uid))
        .toList();
    log("account: orphaned keys = $orphanedKeys");
    return orphanedKeys;
  }

  List<String> getRecentlyDeletedHopKeys() {
    // Get recently deleted hop list keys
    List<OrchidHop> deletedOrchidHops = _recentlyDeleted
        .map((h) => h.hop)
        .where((h) => h is OrchidHop)
        .cast<OrchidHop>()
        .toList();
    log("account: deleted orchid hops = $deletedOrchidHops");
    List<StoredEthereumKeyRef> deletedKeys = deletedOrchidHops.map((h) {
      return h.keyRef;
    }).toList();
    log("account: deleted orchid keys = $deletedKeys");
    List<String> deletedKeyUuids = deletedKeys.map((e) => e.keyUid).toList();
    log("account: deletedKeyUuids = $deletedKeyUuids");

    return deletedKeyUuids;
  }

  Widget _buildInstructions() {
    var s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32),
      child: Text(
          s.toRestoreADeletedHop +
              "\n\n" +
              s.oneClickTheHopBelowThenClickShareOrchidAccount +
              "\n" +
              s.twoReturnToTheManageProfileScreenClickNewHop +
              "\n\n" +
              s.toPermanentlyDeleteAHopFromTheListBelowSwipe,
      style: OrchidText.body2),
    );
  }
}

class OrphanedKeyAccount {
  EthereumAddress funder;
  StoredEthereumKeyRef keyRef;
  String curator;

  OrphanedKeyAccount(this.funder, this.keyRef, this.curator);
}
