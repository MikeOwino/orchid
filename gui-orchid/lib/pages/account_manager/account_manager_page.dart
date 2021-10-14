import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:orchid/api/configuration/orchid_vpn_config/orchid_account_import.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/orchid_eth/token_type.dart';
import 'package:orchid/api/orchid_eth/orchid_account.dart';
import 'package:orchid/api/orchid_platform.dart';
import 'package:orchid/api/orchid_urls.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:orchid/api/purchase/orchid_pac_transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orchid/orchid/orchid_action_button.dart';
import 'package:orchid/orchid/orchid_circular_identicon.dart';
import 'package:orchid/orchid/orchid_colors.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/pages/account_manager/account_detail_store.dart';
import 'package:orchid/pages/circuit/config_change_dialogs.dart';
import 'package:orchid/common/scan_paste_dialog.dart';
import 'package:orchid/common/app_dialogs.dart';
import 'package:orchid/common/formatting.dart';
import 'package:orchid/common/tap_copy_text.dart';
import 'package:orchid/common/titled_page_base.dart';
import 'package:orchid/pages/circuit/model/orchid_hop.dart';
import 'package:orchid/pages/purchase/purchase_page.dart';
import 'package:orchid/pages/purchase/purchase_status.dart';
import 'package:orchid/util/listenable_builder.dart';
import 'package:orchid/util/strings.dart';
import 'package:styled_text/styled_text.dart';

import '../../common/app_sizes.dart';
import '../../common/app_text.dart';
import 'account_card.dart';
import 'account_view_model.dart';
import 'account_store.dart';
import 'export_identity_dialog.dart';

class AccountManagerPage extends StatefulWidget {
  final bool openToImport;
  final bool openToPurchase;
  final Account openToAccount;

  const AccountManagerPage({
    Key key,
    this.openToImport = false,
    this.openToPurchase = false,
    this.openToAccount,
  }) : super(key: key);

  @override
  _AccountManagerPageState createState() => _AccountManagerPageState();
}

class _AccountManagerPageState extends State<AccountManagerPage> {
  var _accountStore = AccountStore();

  AccountDetailStore _accountDetailStore;

  @override
  void initState() {
    super.initState();
    _accountDetailStore =
        AccountDetailStore(onAccountDetailChanged: _accountDetailChanged);
    initStateAsync();
  }

  void initStateAsync() async {
    // Load account info
    _accountStore.addListener(_accountsUpdated);
    await _accountStore.load(waitForDiscovered: false);

    // Open to import, purchase, identity
    await _doOpenOptions();

    await _accountStore.load(waitForDiscovered: true);
  }

  Future<void> _doOpenOptions() async {
    // Open to the supplied account
    if (widget.openToAccount != null) {
      log("XXX: open to account: ${widget.openToAccount}");
      _accountStore.setActiveIdentityByAccount(widget.openToAccount);
    }

    // Open the import dialog after the UI has rendered.
    if (widget.openToImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _importIdentity());
    }

    // Open the purchase dialog after the account info has loaded.
    VoidCallback doAddFunds = _addFunds;
    if (widget.openToPurchase) {
      _accountStore.addListener(() async {
        if (_accountStore.activeIdentity != null && doAddFunds != null) {
          await doAddFunds();
          doAddFunds = null;
        }
      });
    }
  }

  void _accountsUpdated() async {
    // TODO: default circuit from account if needed
    //_defaultActiveAccountIfNeeded();
  }

  /*
  void _defaultActiveAccountIfNeeded() async {
    if (_accountStore.activeAccount == null &&
        _accountStore.accounts.isNotEmpty) {
      log("account_manager: setting default active account: ${_accountStore.accounts.first}");
      await _accountStore.setActiveAccount(_accountStore.accounts.first);
    }
  }
   */

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _accountStore,
        builder: (context, snapshot) {
          return TitledPage(
            title: s.accounts,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildIdentitySelectorMenu(),
              )
            ],
            child: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildIdentityHeader(),
                        pady(8),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 28.0, right: 28.0),
                          child: PurchaseStatus(),
                        ),
                        pady(8),
                        Divider(height: 1),
                        Expanded(child: _buildAccountList()),
                      ],
                    ),
                  ),
                ),

                // The add funds
                if (OrchidPlatform.hasPurchase)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: _buildAddFundsButton(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
  }

  Widget _buildIdentitySelectorMenu() {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: OrchidColors.dark_background,
        highlightColor: OrchidColors.purple_menu,
      ),
      child: PopupMenuButton<IdentitySelectorMenuItem>(
        icon: SvgPicture.asset('assets/svg/settings_gear.svg'),
        initialValue: _accountStore.activeIdentity != null
            ? IdentitySelectorMenuItem(identity: _accountStore.activeIdentity)
            : null,
        onSelected: (IdentitySelectorMenuItem item) async {
          if (item.isIdentity) {
            _accountStore.setActiveIdentity(item.identity);
          } else {
            item.action();
          }
          ConfigChangeDialogs.showConfigurationChangeSuccess(context,
              warnOnly: true);
        },
        itemBuilder: (BuildContext context) {
          var style = OrchidText.body1;
          var items =
              _accountStore.identities.map((StoredEthereumKey identity) {
            var item = IdentitySelectorMenuItem(identity: identity);
            return PopupMenuItem<IdentitySelectorMenuItem>(
              value: item,
              child: Text(item.formatIdentity(), style: style),
            );
          }).toList();

          // Add the import, export actions
          return items +
              [
                PopupMenuItem<IdentitySelectorMenuItem>(
                    value: IdentitySelectorMenuItem(action: _newIdentity),
                    child: Text(s.newWord, style: style)),
                PopupMenuItem<IdentitySelectorMenuItem>(
                    value: IdentitySelectorMenuItem(action: _importIdentity),
                    child: Text(s.import, style: style)),
                PopupMenuItem<IdentitySelectorMenuItem>(
                    value: IdentitySelectorMenuItem(action: _exportIdentity),
                    child: Text(s.export, style: style)),
                PopupMenuItem<IdentitySelectorMenuItem>(
                    value: IdentitySelectorMenuItem(
                        action: _confirmDeleteIdentity),
                    child: Text(s.delete, style: style))
              ];
        },
      ),
    );
  }

  void _importIdentity() {
    ScanOrPasteDialog.show(
      context: context,
      onImportAccount: (ParseOrchidIdentityResult result) async {
        if (result != null) {
          if (result.isNew) {
            await UserPreferences().addKey(result.signer);
            await _accountStore.load(waitForDiscovered: false);
          }
          _accountStore.setActiveIdentity(result.signer);
        }
      },
    );
  }

  void _newIdentity() async {
    var key = StoredEthereumKey.generate();
    await _accountStore.addIdentity(key);
  }

  void _exportIdentity() async {
    var identity = _accountStore.activeIdentity;
    if (identity == null) {
      return;
    }
    var config = 'account={ secret: "${identity.formatSecretFixed()}" }';
    var title = s.exportThisOrchidKey;
    // var bodyStyle = AppText.dialogBody.copyWith(fontSize: 15);
    var bodyStyle = OrchidText.body2;
    // var linkStyle = AppText.linkStyle.copyWith(fontSize: 15);
    var linkStyle = OrchidText.body2.copyWith(color: Colors.deepPurple);

    var body = StyledText(
      style: bodyStyle,
      newLineAsBreaks: true,
      text: s.aQrCodeAndTextForAllTheOrchidAccounts +
          '  ' +
          s.weRecommendBackingItUp +
          '\n\n' +
          s.importThisKeyOnAnotherDeviceToShareAllThe,
      tags: {
        'link': linkStyle.link(OrchidUrls.partsOfOrchidAccount),
      },
    );

    return AppDialogs.showAppDialog(
        context: context,
        title: title,
        body: ExportIdentityDialog(body: body, config: config));
  }

  // Delete the active identity after in-use check and user confirmation.
  void _confirmDeleteIdentity() async {
    var identity = _accountStore.activeIdentity;
    if (identity == null) {
      return;
    }

    List<String> activeKeyUids = await OrchidHop.getInUseKeyUids();

    if (activeKeyUids.contains(identity.uid)) {
      await AppDialogs.showAppDialog(
          context: context,
          title: s.orchidAccountInUse,
          bodyText: s.thisOrchidAccountIsInUseAndCannotBeDeleted);
      return;
    }

    var bodyStyle = AppText.dialogBody; //.copyWith(fontSize: 15);
    var body = RichText(
        text: TextSpan(children: [
      TextSpan(
        text: identity.address.toString().prefix(24) + '\n\n',
        style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: s.thisCannotBeUndone +
            " " +
            s.deletingThisOrchidKeyCanCauseFundsInTheAssociated +
            " ",
        style: bodyStyle,
      ),
      AppText.buildLearnMoreLinkTextSpan(context),
    ]));

    await AppDialogs.showConfirmationDialog(
      context: context,
      title: s.deleteThisOrchidKey,
      body: body,
      cancelText: s.cancel.toUpperCase(),
      //cancelColor: bodyStyle.color,
      actionText: s.delete.toUpperCase(),
      // Localize all caps version
      actionColor: Colors.red,
      commitAction: () {
        _deleteIdentity(identity);
      },
    );
  }

  void _deleteIdentity(StoredEthereumKey identity) async {
    await _accountStore.deleteIdentity(identity);
  }

  Column _buildIdentityHeader() {
    return Column(
      children: [
        pady(12),
        if (_accountStore.activeIdentity != null)
          OrchidCircularIdenticon(
              address: _accountStore.activeIdentity.address),
        pady(24),
        Text(s.orchidIdentity, style: OrchidText.body2),
        if (_accountStore.activeIdentity != null)
          Container(
            width: AppSize(context).widerThan(AppSize.iphone_12_pro_max)
                ? null
                : 238,
            child: Center(
              child: TapToCopyText(
                _accountStore.activeIdentity.address.toString(),
                key: ValueKey(_accountStore.activeIdentity.address.toString()),
                padding: EdgeInsets.only(top: 8, bottom: 8),
                style:
                    OrchidText.caption.copyWith(color: OrchidColors.tappable),
                onTap: (String text) async {
                  await TapToCopyText.copyTextToClipboard(text);
                  _showOrchidAccountAddressWarning();
                },
              ),
            ),
          )
        else
          pady(16)
      ],
    );
  }

  Future<void> _showOrchidAccountAddressWarning() async {
    var title = s.copiedOrchidIdentity;
    var body = StyledText(
      style: OrchidText.body2,
      newLineAsBreaks: true,
      text: "<alarm/> <bold>" +
          s.thisIsNotAWalletAddress +
          "</bold>" +
          "  " +
          s.doNotSendTokensToThisAddress +
          "\n\n" +
          s.yourOrchidIdentityUniquelyIdentifiesYouOnTheNetwork +
          "  " +
          s.learnMoreAboutYourLinkorchidIdentitylink,
      tags: {
        'bold': StyledTextTag(
          style: OrchidText.body2.purpleBright.bold,
        ),
        'link': OrchidText.linkStyle.link(OrchidUrls.partsOfOrchidAccount),
        'alarm': StyledTextIconTag(Icons.warning_amber_rounded,
            color: OrchidColors.purple_bright)
      },
    );
    return AppDialogs.showAppDialog(
      context: context,
      title: title,
      body: body,
    );
  }

  Widget _buildAccountList() {
    var signerKey = _accountStore.activeIdentity;
    List<AccountViewModel> accounts = _accountStore.accounts
        // accounts may be for identity selection only, remove those
        .where((a) => a.funder != null)
        .map((Account account) {
      return AccountViewModel(
          chain: Chains.chainFor(account.chainId),
          signerKey: signerKey,
          funder: account.funder,
          // TODO:
          // active: account == activeAccount,
          detail: _accountDetailStore.get(account));
    }).toList();

    // Sort by efficiency descending
    accounts.sort((AccountViewModel a, AccountViewModel b) {
      return -((a.detail?.marketConditions?.efficiency ?? 0)
          .compareTo((b.detail?.marketConditions?.efficiency ?? 0)));
    });

    Widget footer() {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 128),
        child: Align(
            child: Column(
          children: [
            Text(s.pullToRefresh, style: OrchidText.caption),
          ],
        )),
      );
    }

    var accountListView = accounts.isEmpty
        ? ListView(
            children: [pady(8), footer()],
          )
        : ListView.separated(
            separatorBuilder: (BuildContext context, int index) =>
                Container(height: 24),
            key: PageStorageKey('account list view'),
            primary: true,
            itemCount: accounts.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == accounts.length) {
                return footer();
              }
              var account = accounts[index];
              return Container(
                key: Key(account.toString()),
                alignment: Alignment.center,
                child: _buildAccountCard(account, index),
              );
            });

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: OrchidColors.purple_ffb88dfc,
      displacement: 0,
      onRefresh: () async {
        // Refresh the account details
        _accountDetailStore.refresh();

        // Look for new accounts
        return _accountStore.load(); // Return the load future
      },
      child: accountListView,
    );
  }

  Widget _buildAccountCard(AccountViewModel accountModel, int index) {
    return AccountCard(
      key: Key(accountModel.toString()),
      accountDetail: accountModel.detail,
      active: accountModel.active,
      initiallyExpanded: widget.openToAccount != null &&
          accountModel.detail.account == widget.openToAccount,
      //selected: accountModel.active,
      // onSelected: () {
      //   if (!accountModel.active) {
      //     _setActiveAccount(accountModel);
      //   }
      // },
    );
  }

  Widget _buildAddFundsButton() {
    return StreamBuilder<PacTransaction>(
        stream: PacTransaction.shared.stream(),
        builder: (context, snapshot) {
          var tx = snapshot.data;
          var enabled = _accountStore.activeIdentity != null && tx == null;
          return OrchidActionButton(
            enabled: enabled,
            text: s.addFunds,
            onPressed: _addFunds,
          );
        });
  }

  /*
  void _setActiveAccount(AccountViewModel account) {
    _accountStore.setActiveAccount(account.detail.account); // a bit convoluted
    ConfigChangeDialogs.showConfigurationChangeSuccess(context, warnOnly: true);
  }
   */

  void _addFunds() async {
    var signerKey = _accountStore.activeIdentity;
    if (signerKey == null) {
      throw Exception("iap: no signer!");
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (BuildContext context) {
            return PurchasePage(
                signerKey: signerKey,
                cancellable: true,
                completion: () {
                  log("purchase complete");
                });
          }),
    );
  }

  void _accountDetailChanged() {
    setState(() {}); // Trigger a UI refresh
  }

  @override
  void dispose() {
    _accountDetailStore.dispose();
    _accountStore.removeListener(_accountsUpdated);
    super.dispose();
  }

  S get s {
    return S.of(context);
  }
}

class IdentitySelectorMenuItem {
  /// Either an identity...
  final StoredEthereumKey identity;

  /// ...or an action with label
  final Function() action;

  IdentitySelectorMenuItem({this.identity, this.action});

  bool get isIdentity {
    return identity != null;
  }

  String formatIdentity() {
    return identity?.address?.toString()?.prefix(12) ?? '???';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentitySelectorMenuItem &&
          runtimeType == other.runtimeType &&
          identity == other.identity &&
          action == other.action;

  @override
  int get hashCode => identity.hashCode ^ action.hashCode;
}
