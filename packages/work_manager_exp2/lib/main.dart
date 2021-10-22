import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp2/src/client.dart';
import 'package:work_manager_exp2/src/import.dart';
import 'package:work_manager_exp2/src/ui.dart';
import 'package:work_manager_exp_common/tracker_db.dart';
import 'package:work_manager_exp_common/tracker_service_client.dart';
import 'package:workmanager/workmanager.dart';

const periodicTaskName = 'periodicTask';
const runOnceTaskName = 'runOnceTask';

var _id = 0;

Future<void> serviceRun(TrackerServiceClient client, String tag) async {
  //var client = TrackerServiceClient();
  print('Workmanager starting serviceRun');
  await client.ping('test1');
  await client.workOnce(WorkOnceRequest()..tag.v = tag);
  await client.ping('test2');
  print('Workmanager ending serviceRun');
}

void callbackDispatcher() {
  print('Workmanager callbackDispatcher()');
  Workmanager().executeTask((task, inputData) async {
    _id++;
    print('Workmanager task $task ${Isolate.current.debugName} $_id');
    var success = false;
    try {
      var client = await getClient();

      switch (task) {
        case Workmanager.iOSBackgroundTask:
          stderr.writeln('The iOS background fetch was triggered');
          await serviceRun(client, 'ios');
          break;
        case periodicTaskName:
          stderr.writeln('The Android periodic triggered');
          await serviceRun(client, 'back');
          break;
        case runOnceTaskName:
          stderr.writeln('The Android manually triggered');
          await serviceRun(client, 'trig');
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
          isDebug // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
      );
}

Future<void> main() async {
  _id++;
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
  }
  client = await getClient();
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

  runApp(const MyApp());
}
