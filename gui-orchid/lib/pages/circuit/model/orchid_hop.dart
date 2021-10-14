import 'package:flutter/foundation.dart';
import 'package:orchid/api/orchid_crypto.dart';
import 'package:orchid/api/orchid_eth/orchid_account.dart';
import 'package:orchid/api/orchid_eth/token_type.dart';
import 'package:orchid/api/orchid_log_api.dart';
import 'package:orchid/api/preferences/user_preferences.dart';

import 'circuit_hop.dart';

class OrchidHop extends CircuitHop {
  // The app default, which may be overridden by the user specified settings
  // default or on a per-hop basis.
  static const String appDefaultCurator = "partners.orch1d.eth";

  /// Curator URI
  final String curator;

  /// Signer key uid
  final StoredEthereumKeyRef keyRef;

  /// Funder address
  final EthereumAddress funder;

  /// The contract version: 0 for the original OXT contract.
  final int version;

  /// The contract version: 1 for Ethereum for the original OXT contract.
  final int chainId;

  // This transient field supports testing without hitting the keystore.
  EthereumAddress resolvedSignerAddress;

  /// The Orchid Account associated with this hop.
  // Note: This is a migration from the v0 storage and should eventually replace it.
  Account get account {
    return Account(
      identityUid: keyRef?.keyUid,
      funder: funder,
      version: version,
      chainId: chainId,
      resolvedSignerAddress: resolvedSignerAddress,
    );
  }

  OrchidHop({
    @required this.curator,
    @required this.funder,
    @required this.keyRef,
    @required this.version,
    @required this.chainId,
    this.resolvedSignerAddress,
  }) : super(HopProtocol.Orchid);

  OrchidHop.fromAccount(Account account)
      : this(
          curator: appDefaultCurator,
          funder: account.funder,
          keyRef: account.signerKeyRef,
          version: account.version,
          chainId: account.chainId,
          resolvedSignerAddress: account.resolvedSignerAddress,
        );

  OrchidHop.v0({
    @required this.curator,
    @required this.funder,
    @required this.keyRef,
  })  : this.version = 0,
        this.chainId = Chains.ETH_CHAINID,
        super(HopProtocol.Orchid);

  // Construct an Orchid Hop using an existing hop's properties as defaults.
  // The hop may be null, in which case this serves as a loose constructor.
  OrchidHop.from(
    OrchidHop hop, {
    String curator,
    EthereumAddress funder,
    StoredEthereumKeyRef keyRef,
    int version,
    int chainId,
  }) : this(
          curator: curator ?? hop?.curator,
          funder: funder ?? hop?.funder,
          keyRef: keyRef ?? hop?.keyRef,
          version: version ?? hop?.version,
          chainId: chainId ?? hop?.chainId,
        );

  OrchidHop.fromJson(Map<String, dynamic> json)
      : this.curator = json['curator'] ?? appDefaultCurator,
        this.funder = EthereumAddress.from(json['funder']),
        this.keyRef = StoredEthereumKeyRef(json['keyRef']),

        // Migrate version from legacy v0 if null
        this.version = json['version'] ?? 0,
        // Migrate chainId from legacy v0 if null
        this.chainId = json['chainId'] ?? Chains.ETH_CHAINID,
        super(HopProtocol.Orchid);

  Map<String, dynamic> toJson() => {
        'curator': curator,
        'protocol': CircuitHop.protocolToString(protocol),
        // Always render funder with the hex prefix as required by the config.
        'funder': funder.toString(prefix: true),
        'keyRef': keyRef.toString(),
        'version': version,
        'chainId': chainId,
      };

  /// Return key uids for configured hops
  static Future<List<String>> getInUseKeyUids() async {
    // Get the active hop keys
    var activeHops = (await UserPreferences().getCircuit()).hops;
    List<OrchidHop> activeOrchidHops =
        activeHops.where((h) => h is OrchidHop).cast<OrchidHop>().toList();
    List<StoredEthereumKeyRef> activeKeys = activeOrchidHops.map((h) {
      return h.keyRef;
    }).toList();
    List<String> activeKeyUids = activeKeys.map((e) => e.keyUid).toList();
    log("account: activeKeyUuids = $activeKeyUids");
    return activeKeyUids;
  }

  // TODO: Remove in favor of "show account in account manager"
  // ...
  // TODO: migrate this to use the orchid_vpn_config code
  // TODO: Remove or update for V1 accounts (rendering the correct protocol, chainid, etc.
  @deprecated
  Future<String> accountConfigString() async {
    var funder = this.funder.toString();
    var secret = (await this.keyRef.get()).private.toRadixString(16);
    return 'account={ protocol: "orchid", funder: "$funder", secret: "$secret" }';
  }

  @override
  String toString() {
    return 'OrchidHop{curator: $curator, keyRef: $keyRef, funder: $funder, version: $version, chainId: $chainId, resolvedSignerAddress: $resolvedSignerAddress}';
  }
}
