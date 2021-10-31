import 'package:cv/cv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:work_manager_exp4/src/push_messaging_service.dart';

bool gDebug = isDebug;

late PushMessagingService gPushMessagingService;
final gFlutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

final gSelectNotificationSubject = BehaviorSubject<String>();
final gAppNotificationSubject = BehaviorSubject<Model?>();
final gHomeNotificationSubject = BehaviorSubject<Model?>();
// To override in prod
bool gProd = false;
