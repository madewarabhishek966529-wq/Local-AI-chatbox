import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Whether the device currently has any network path at all (Wi-Fi/LAN/
/// ethernet). This does NOT guarantee the backend container is up — it's
/// a cheap first check the UI uses to decide whether to attempt a sync or
/// go straight to Hive-cached data.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
});

/// True once we've confirmed the local backend actually responded (set by
/// the chat/auth repositories after a successful call). Distinct from raw
/// network connectivity: you can be on Wi-Fi with the backend container
/// stopped.
class BackendReachability extends StateNotifier<bool> {
  BackendReachability() : super(true);

  void markReachable() {
    if (!state) state = true;
  }

  void markUnreachable() {
    if (state) state = false;
  }
}

final backendReachabilityProvider =
    StateNotifierProvider<BackendReachability, bool>(
      (ref) => BackendReachability(),
    );
