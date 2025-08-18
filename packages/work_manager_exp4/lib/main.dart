import 'dart:io';
import 'dart:isolate';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:work_manager_exp4/src/client.dart';
import 'package:work_manager_exp4/src/globals.dart';
import 'package:work_manager_exp4/src/import.dart';
import 'package:work_manager_exp4/src/push_messaging_service.dart';
import 'package:work_manager_exp4/src/ui.dart';
import 'package:work_manager_exp_common/tracker_db.dart';
import 'package:work_manager_exp_common/tracker_service.dart';
import 'package:workmanager/workmanager.dart';

late TrackerService service;

const periodicTaskName = 'periodicTask';
const runOnceTaskName = 'runOnceTask';

var _id = 0;
var flip = FlutterLocalNotificationsPlugin();
void requestNotificationPermissions() {
  flip
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
  flip
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

/// Main service entry.
///
/// The service runs for at about 3mn if not interrupted.
///
/// It:
/// - performs in loops
///   - http fetch
///   - sqflite transaction
Future<void> serviceBgRun(TrackerService service, String tag) async {
  //var client = TrackerServiceClient();
  var mutex = Mutex(mutexName);
  var done = false;

  // Handle cancel when main request it
  () async {
    while (!done) {
      if (await mutex.getData<Object?>(mainRequestKeyName) == true) {
        service.isKilled = true;
      }
    }
  }().unawait();

  print('Workmanager starting serviceRun $tag');
  await service.workOnce(tag: tag);

  print('Workmanager ending serviceRun $tag');
}

void callbackDispatcher() {
  print('Workmanager callbackDispatcher()');
  Workmanager().executeTask((task, inputData) async {
    _id++;
    print('Workmanager task $task ${Isolate.current.debugName} $_id');
    var success = false;
    try {
      var service = await getTrackerService();

      switch (task) {
        case Workmanager.iOSBackgroundTask:
          stderr.writeln('The iOS background fetch was triggered');
          await serviceBgRun(service, 'ios');
          break;
        case periodicTaskName:
          stderr.writeln('The Android periodic triggered');
          await serviceBgRun(service, 'back');
          break;
        case runOnceTaskName:
          stderr.writeln('The Android manually triggered');
          await serviceBgRun(service, 'trig');
          break;
      }
      success = true;
    } catch (e, st) {
      print(e);
      print(st);
    }
    return success;
  });
}

void initializeWorkmanager() {
  Workmanager().initialize(
    callbackDispatcher, // The top level function, aka callbackDispatcher
  );
}

const mutexName = 'appMutex';
const mainRequestKeyName = 'mainRequest';
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();
  _id++;
  var mutex = Mutex(mutexName);

  await mutex.setData(mainRequestKeyName, false);
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
  }
  service = await getTrackerService();
  initTrackerBuilders();
  initializeWorkmanager();

  /// Firebase
  await Firebase.initializeApp();
  // Periodic task registration, android only
  if (Platform.isAndroid) {
    try {
      await Workmanager().registerPeriodicTask('100', periodicTaskName);
    } catch (e) {
      print('Error #e');
    }
  }

  /// While running do every 10mn
  ///
  /// Until the app is killed somehow...
  () async {
    while (true) {
      try {
        await service.workOnce(tag: tagFront);
      } catch (_) {}

      await sleep(10 * 60 * 1000);
    }
  }().unawait();

  gPushMessagingService = PushMessagingService();
  const initializationSettingsAndroid = AndroidInitializationSettings(
    'ic_notification',
  );
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  final notificationAppLaunchDetails = !kIsWeb && Platform.isLinux
      ? null
      : await gFlutterLocalNotificationsPlugin
            .getNotificationAppLaunchDetails();
  var payload = notificationAppLaunchDetails?.notificationResponse?.payload;
  if (payload != null) {
    gSelectNotificationSubject.add(payload);
  }
  await gFlutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse:
        (NotificationResponse? response) async {
          var payload = response?.payload;
          if (payload != null) {
            gSelectNotificationSubject.add(payload);
          } else {
            debugPrint('notification payload null');
          }
          debugPrint('notification payload: $payload');
          Model data;
          try {
            data = asModel(jsonDecode(payload!) as Map);
          } catch (_) {
            data = newModel();
          }
          gAppNotificationSubject.add(data);
        },
  );
  () async {
    try {
      await gPushMessagingService.init();
    } catch (e) {
      debugPrint('push amessaging init failed $e');
    }
  }().unawait();
  runApp(const MyApp());
}
