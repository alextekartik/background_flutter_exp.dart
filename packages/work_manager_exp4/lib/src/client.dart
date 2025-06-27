import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:work_manager_exp4/main.dart';
import 'package:work_manager_exp_common/tracker_service.dart';

Future<TrackerService> getTrackerService() async {
  var directory = await getApplicationSupportDirectory();
  var mutex = Mutex(mutexName);
  DatabaseFactory factory;
  // Supported sqflite platforms
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    sqfliteFfiInit();
    factory = databaseFactory;
    if (Platform.isAndroid) {
      directory = Directory(await getDatabasesPath());
    }
  } else {
    factory = databaseFactoryFfi;
  }
  final service = TrackerService(factory, dbDir: directory.path);
  service.dbMutex = mutex;
  return service;
}
