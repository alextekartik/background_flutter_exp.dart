import 'package:flutter/material.dart';
import 'package:work_manager_exp4/src/import.dart';
import 'package:work_manager_exp4/src/ui.dart';

import 'globals.dart';

class AppNotification extends StatefulWidget {
  final Widget child;
  const AppNotification({Key? key, required this.child}) : super(key: key);

  @override
  _AppNotificationState createState() => _AppNotificationState();
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

void popAllAndGoToHomeScreen(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TrackItemListPage()),
      (route) => false);
}
