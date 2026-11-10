import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_manager_exp4/src/globals.dart';
import 'package:work_manager_exp4/src/push_messaging_service.dart';
import 'package:work_manager_exp4/src/ui.dart';

/// No Firebase in a test.
class _NoPushMessagingService extends PushMessagingService {
  @override
  Future<void> init() async {}
}

void main() {
  testWidgets('notification data opens the home screen', (tester) async {
    gPushMessagingService = _NoPushMessagingService();
    // The list screen asks for the notification permissions.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await tester.pumpWidget(const MyApp());
    expect(find.byType(TrackItemListPage), findsOneWidget);

    gAppNotificationSubject.add({'type': 'test'});
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // A new home screen is pushed, the old one leaves with the transition.
    expect(find.byType(TrackItemListPage), findsNWidgets(2));

    // Unmount before the list loop timer runs (no tracker service here).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
