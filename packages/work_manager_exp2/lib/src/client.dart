import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_manager_exp_common/tracker_service.dart';
import 'package:work_manager_exp_common/tracker_service_client.dart';

class _TrackerServiceClient with TrackerServiceClientMixin {
  final TrackerService service;

  _TrackerServiceClient(this.service);

  @override
  Future<Object?> sendCommand(String method, [Object? param]) async {
    var result = await service.onCommand(method, param);
    return result;
  }
}

Future<TrackerServiceClient> getClient() async {
  var directory = await getApplicationSupportDirectory();
  final service = TrackerService(databaseFactoryFfi, dbDir: directory.path);
  return _TrackerServiceClient(service);
}
