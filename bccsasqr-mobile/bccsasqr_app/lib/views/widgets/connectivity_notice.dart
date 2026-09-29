import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../services/connectivity.dart';
import 'island.dart';

/// Says on the island when the phone loses its connection, and again when it
/// comes back — so a failed look-up or scan is never the first sign.
///
/// Opening the app online says nothing; opening it offline says so once.
/// Sits under [IslandHost], over every page, so it speaks wherever the
/// person is.
class ConnectivityNotice extends StatefulWidget {
  const ConnectivityNotice({
    super.key,
    required this.connectivity,
    required this.child,
  });

  /// Nothing is watched without one.
  final ConnectivityService? connectivity;
  final Widget child;

  @override
  State<ConnectivityNotice> createState() => _ConnectivityNoticeState();
}

class _ConnectivityNoticeState extends State<ConnectivityNotice> {
  StreamSubscription<bool>? _subscription;

  /// What was last said — null until the first reading.
  bool? _online;

  @override
  void initState() {
    super.initState();
    _subscription = widget.connectivity?.online.listen(_onChange);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onChange(bool online) {
    final was = _online;
    if (was == online) return;
    _online = online;
    // The first reading only sets the baseline, unless it is bad news.
    if (!mounted || (was == null && online)) return;

    Island.show(
      context,
      online
          ? const IslandMessage(
              title: OfflineStrings.back,
              tone: IslandTone.success,
              icon: Icons.wifi_rounded,
            )
          : const IslandMessage(
              title: OfflineStrings.title,
              body: OfflineStrings.body,
              tone: IslandTone.warning,
              icon: Icons.wifi_off_rounded,
              hold: Duration(seconds: 5),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
