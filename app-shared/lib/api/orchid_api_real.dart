import 'dart:async';
import 'package:flutter/services.dart';
import 'package:orchid/api/orchid_api.dart';
import 'package:orchid/api/orchid_types.dart';
import 'package:orchid/util/ip_address.dart';
import 'package:orchid/util/location.dart';
import 'package:rxdart/rxdart.dart';

import 'orchid_budget_api.dart';
import 'orchid_log_api.dart';

class RealOrchidAPI implements OrchidAPI {
  static final RealOrchidAPI _singleton = RealOrchidAPI._internal();
  static const _platform = const MethodChannel("orchid.com/feedback");

  factory RealOrchidAPI() {
    return _singleton;
  }

  RealOrchidAPI._internal() {
    _platform.setMethodCallHandler((MethodCall call) async {
      //print("Method call handler: $call");
      switch (call.method) {
        case 'connectionStatus':
          switch (call.arguments) {
            case 'Invalid':
              connectionStatus.add(OrchidConnectionState.NotConnected);
              break;
            case 'Disconnected':
              connectionStatus.add(OrchidConnectionState.NotConnected);
              break;
            case 'Connecting':
              connectionStatus.add(OrchidConnectionState.Connecting);
              break;
            case 'Connected':
              connectionStatus.add(OrchidConnectionState.Connected);
              break;
            case 'Disconnecting':
              connectionStatus.add(OrchidConnectionState.NotConnected);
              break;
            case 'Reasserting':
              connectionStatus.add(OrchidConnectionState.Connecting);
              break;
          }
          break;

        case 'providerStatus':
          //print("ProviderStatus called in API: ${call.arguments}");
          vpnPermissionStatus.add(call.arguments);
          break;

        case 'route':
          routeStatus.add(call.arguments
              .map((route) => OrchidNode(
                    ip: IPAddress(route),
                    location: Location(),
                  ))
              .toList());
          break;
      }
    });
  }

  final networkConnectivity = BehaviorSubject<NetworkConnectivityType>.seeded(
      NetworkConnectivityType.Unknown);
  final connectionStatus = BehaviorSubject<OrchidConnectionState>();
  final syncStatus = BehaviorSubject<OrchidSyncStatus>();
  final routeStatus = BehaviorSubject<OrchidRoute>();
  final vpnPermissionStatus = BehaviorSubject<bool>();

  /// Transient, in-memory log implementation.
  OrchidLogAPI _logAPI = MemoryOrchidLogAPI();

  /// The Flutter application uses this method to indicate to the native channel code
  /// that the UI has finished launching and all listeners have been established.
  Future<void> applicationReady() {
    budget().applicationReady();
    return _platform.invokeMethod('ready');
  }
  /// Get the logging API.
  @override
  OrchidLogAPI logger() {
    return _logAPI;
  }

  @override
  Future<bool> requestVPNPermission() {
    return _platform.invokeMethod('install');
  }

  Future<void> revokeVPNPermission() async {
    // TODO:
  }

  @override
  Future<bool> setWallet(OrchidWallet wallet) {
    return Future<bool>.value(false);
  }

  @override
  Future<void> clearWallet() async {}

  @override
  Future<OrchidWalletPublic> getWallet() {
    return Future<OrchidWalletPublic>.value(null);
  }

  @override
  Future<bool> setExitVPNConfig(VPNConfig vpnConfig) {
    return Future<bool>.value(false);
  }

  @override
  Future<VPNConfigPublic> getExitVPNConfig() {
    return Future<VPNConfigPublic>.value(null);
  }

  @override
  Future<void> setConnected(bool connect) async {
    if (connect)
      await _platform.invokeMethod('connect');
    else
      await _platform.invokeMethod('disconnect');
  }

  @override
  Future<void> reroute() async {
    await _platform.invokeMethod('reroute');
  }

  @override
  Future<Map<String, String>> getDeveloperSettings() async {
    return Map();
  }

  @override
  void setDeveloperSetting({String name, String value}) {
    // TODO:
  }

  @override
  OrchidBudgetAPI budget() {
    return OrchidBudgetAPI();
  }

  Future<String> groupContainerPath() async {
    return _platform.invokeMethod('group_path');
  }

  Future<String> versionString() async {
    return _platform.invokeMethod('version');
  }
}

