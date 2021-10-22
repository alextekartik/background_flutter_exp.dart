import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:sqflite_common/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_manager_exp_common/src/tracker_bg_model.dart';
import 'package:work_manager_exp_common/src/tracker_service.dart';
import 'package:work_manager_exp_common/src/tracker_service_client.dart';

class _TrackerServiceClient with TrackerServiceClientMixin {
  late TrackerService service;

  @override
  Future<Object?> sendCommand(String method, [Object? param]) {
    return service.onCommand(method, param);
  }
}

void main() {
  sqfliteFfiInit();
  initTrackerBuilders();
  var databaseFactory = databaseFactoryFfi;
  test('service', () async {
    // databaseFactory.setLogLevel(sqfliteLogLevelVerbose);
    var service = TrackerService(databaseFactory);
    await service.onWorkOnce((WorkOnceRequest()..durationMs.v = 10).toMap());
  });
  test('client', () async {
    // databaseFactory.setLogLevel(sqfliteLogLevelVerbose);
    var service = TrackerService(databaseFactory);
    var client = _TrackerServiceClient()..service = service;
    var response =
        await client.workOnce(WorkOnceRequest()..durationMs.v = 6000);
    expect(response.count.v, greaterThanOrEqualTo(4));
    expect(response.count.v, lessThanOrEqualTo(6));
  });
}
