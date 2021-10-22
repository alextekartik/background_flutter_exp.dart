import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_manager_exp_common/tracker_service.dart';

Future<TrackerService> getTrackerService() async {
  var directory = await getApplicationSupportDirectory();
  final service = TrackerService(databaseFactoryFfi, dbDir: directory.path);
  return service;
}
