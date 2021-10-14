import 'package:flutter/material.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/orchid_account.dart';
import 'package:orchid/api/preferences/user_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:orchid/orchid/orchid_text.dart';
import 'package:orchid/orchid/orchid_text_field.dart';

typedef FunderSelectionCallback = void Function(FunderSelectionItem key);

class FunderSelectionDropdown extends StatefulWidget {
  final FunderSelectionCallback onSelection;
  final FunderSelectionItem initialSelection;
  final bool enabled;
  final StoredEthereumKeyRef signer;

  // Fixed options
  static final pasteKeyOption =
      FunderSelectionMenuOption(displayStringGenerator: (context) {
    return S.of(context).pasteAddress;
  });

  FunderSelectionDropdown({
    Key key,
    @required this.signer,
    @required this.onSelection,
    this.initialSelection,
    bool enabled = false,
  })  : this.enabled = signer == null ? false : enabled,
        super(key: key);

  @override
  _FunderSelectionDropdownState createState() =>
      _FunderSelectionDropdownState();
}

class _FunderSelectionDropdownState extends State<FunderSelectionDropdown> {
  StoredEthereumKey _signer;
  List<Account> _funderAccounts = [];
  FunderSelectionItem _selectedItem;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    _signer = await widget.signer.get();
    var cached = await UserPreferences().cachedDiscoveredAccounts.get();
    _funderAccounts =
        cached.where((account) => account.identityUid == _signer.uid).toList();

    // If the cached accounts list does not include the selected funder add it.
    // This can happen if the user pasted a prospective account that hasn't been
    // funded yet.
    if (widget.initialSelection?.account != null &&
        !_funderAccounts.contains(widget.initialSelection?.account)) {
      _funderAccounts.add(widget.initialSelection.account);
    }

    // If an initial key selection is provided use it
    if (widget.initialSelection != null) {
      this._selectedItem = widget.initialSelection;
    }

    // Update all state
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16),
      decoration:
          widget.enabled ? OrchidTextField.textFieldEnabledDecoration : null,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Container(
          child: DropdownButton<FunderSelectionItem>(
            dropdownColor: OrchidTextField.textFieldEnabledDecoration.color,
            hint: Text(s.chooseAddress, style: OrchidText.button),
            isExpanded: true,
            icon: !widget.enabled ? Icon(Icons.add, size: 0) : null,
            underline: Container(),
            // suppress the underline
            value: _selectedItem,
            items: _getDropdownItems(),
            onChanged: (FunderSelectionItem item) {
              setState(() {
                _selectedItem = item;
              });
              widget.onSelection(item);
            },
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<FunderSelectionItem>> _getDropdownItems() {
    List<DropdownMenuItem<FunderSelectionItem>> items = [];

    if (_funderAccounts != null) {
      items.addAll(_funderAccounts.map((account) {
        return new DropdownMenuItem<FunderSelectionItem>(
          value: FunderSelectionItem(funderAccount: account),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: SizedBox(width: 24, height: 24, child: account.chain.icon),
              ),
              Flexible(
                child: Text(
                  account.funder.toString(prefix: true),
                  overflow: TextOverflow.ellipsis,
                  style: OrchidText.button,
                ),
              ),
            ],
          ),
        );
      }).toList());
    }

    // Add the fixed options
    items.addAll([
      DropdownMenuItem<FunderSelectionItem>(
        value:
            FunderSelectionItem(option: FunderSelectionDropdown.pasteKeyOption),
        child: Text(
          FunderSelectionDropdown.pasteKeyOption.displayName(context),
          style: OrchidText.button,
        ),
      ),
    ]);

    return items;
  }

  S get s {
    return S.of(context);
  }
}

/// Represents a fixed option such as 'generate a new key'
class FunderSelectionMenuOption {
  String Function(BuildContext context) displayStringGenerator;

  String displayName(BuildContext context) {
    return displayStringGenerator(context);
  }

  FunderSelectionMenuOption({this.displayStringGenerator});
}

/// An item in the key selection drop down list.
/// Holds either an account (representing the funder) or a selection option.
class FunderSelectionItem {
  Account account;
  FunderSelectionMenuOption option;

  FunderSelectionItem({
    Account funderAccount,
    FunderSelectionMenuOption option,
  }) {
    assert(funderAccount == null || option == null);
    this.account = funderAccount;
    this.option = option;
  }

  bool operator ==(o) =>
      o is FunderSelectionItem && o.option == option && o.account == account;

  @override
  int get hashCode => super.hashCode;

  @override
  String toString() {
    return 'FunderSelectionItem{keyRef: $account, option: $option}';
  }
}
