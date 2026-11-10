import 'package:flutter/material.dart';
import 'package:work_manager_exp4/src/import.dart';
import 'package:work_manager_exp4/src/ui.dart';

import 'globals.dart';

class AppNotification extends StatefulWidget {
  final Widget child;
  const AppNotification({super.key, required this.child});

  @override
  State<AppNotification> createState() => _AppNotificationState();
}

class _AppNotificationState extends State<AppNotification> {
  StreamSubscription? _notificationSubscription;
  @override
  void initState() {
    _notificationSubscription = gAppNotificationSubject.listen((data) {
      // devPrint('Received notification $data');
      if (data == null) {
        return;
      }
      gHomeNotificationSubject.add(data);
      if (mounted) {
        popAllAndGoToHomeScreen(context);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Shows a fresh home screen. [context] can be above the app navigator (as
/// the one of [AppNotification]): [gNavigatorKey] is used then.
void popAllAndGoToHomeScreen(BuildContext context) {
  var navigator = Navigator.maybeOf(context) ?? gNavigatorKey.currentState;
  navigator?.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const TrackItemListPage()),
    (route) => false,
  );
}
