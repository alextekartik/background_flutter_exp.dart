import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:sqflite_common/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/src/tracker_model.dart';
import 'package:work_manager_exp_common/src/tracker_service.dart';

void main() {
  sqfliteFfiInit();
  initTrackerBuilders();
  var databaseFactory = databaseFactoryFfi;
  test('service', () async {
    // databaseFactory.setLogLevel(sqfliteLogLevelVerbose);
    var service = TrackerService(databaseFactory);
    await service.workOnce(durationMs: 10);
  });
  test('workOnce', () async {
    // databaseFactory.setLogLevel(sqfliteLogLevelVerbose);
    var service = TrackerService(databaseFactory);
    var count = await service.workOnce(durationMs: 6000);
    expect(count, greaterThanOrEqualTo(4));
    expect(count, lessThanOrEqualTo(6));
  });
  test('workOnce cancel', () async {
    // databaseFactory.setLogLevel(sqfliteLogLevelVerbose);
    var service = TrackerService(databaseFactory);
    sleep(10000).then((_) => service.isKilled = true).unawait();
    var count = await service.workOnce(durationMs: 60000);

    expect(count, greaterThanOrEqualTo(4));
    expect(count, lessThanOrEqualTo(6));
  });
}
