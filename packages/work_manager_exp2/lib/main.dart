import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp2/src/client.dart';
import 'package:work_manager_exp2/src/import.dart';
import 'package:work_manager_exp2/src/ui.dart';
import 'package:work_manager_exp_common/tracker_db.dart';
import 'package:work_manager_exp_common/tracker_service.dart';
import 'package:workmanager/workmanager.dart';

const periodicTaskName = 'periodicTask';
const runOnceTaskName = 'runOnceTask';

var _id = 0;

Future<void> serviceBgRun(TrackerService service, String tag) async {
  //var client = TrackerServiceClient();
  var mutex = Mutex(mutexName);
  var done = false;
  await mutex.synchronized((mutex) async {
    // Handle cancel when main request it
    () async {
      while (!done) {
        if (await mutex.getData<Object?>(mainRequestKeyName) == true) {
          service.isKilled = true;
        }
      }
    }()
        .unawait();

    print('Workmanager starting serviceRun $tag');
    await service.workOnce(tag: tagBackground);

    print('Workmanager ending serviceRun $tag');
  }, cancel: () {
    stdout.writeln('Bg waiting...');
    return false;
  }, timeout: const Duration(milliseconds: 10000));
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
      isInDebugMode:
          false // isDebug // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
      );
}

const mutexName = 'appMutex';
const mainRequestKeyName = 'mainRequest';
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();
  _id++;
  var mutex = Mutex(mutexName);
  await mutex.acquire(cancel: () {
    stdout.writeln('Main waiting...');
    mutex.setData(mainRequestKeyName, true);
    return false;
  });
  await mutex.setData(mainRequestKeyName, false);
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
  }
  service = await getTrackerService();
  initTrackerBuilders();
  initializeWorkmanager();
  // Periodic task registration, android only
  if (Platform.isAndroid) {
    try {
      await Workmanager().registerPeriodicTask(
        '100',
        periodicTaskName,
      );
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
  }()
      .unawait();

  runApp(const MyApp());
}
