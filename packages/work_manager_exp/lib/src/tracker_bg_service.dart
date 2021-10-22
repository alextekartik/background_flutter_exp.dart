import 'package:cv/cv.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:tekartik_app_flutter_bg_isolate/bg_isolate.dart';
import 'package:tekartik_app_flutter_sqflite/sqflite.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/tracker_service.dart';

class TrackerBgService extends AppBgServiceBase {
  late final TrackerService service;
  final DatabaseFactory databaseFactory;

  TrackerBgService(this.databaseFactory) {
    service = TrackerService(databaseFactory);
  }

  Future<int> getLastId(DatabaseExecutor executor) =>
      service.getLastId(executor);

  Future<Model> onListItems() => service.onListItems();

  Future<void> onClearItems() => service.onClearItems();

  @override
  Future<Object?> onCommand(String method, Object? param) async {
    var result = await service.onCommand(method, param);
    if (result == null) {
      return result;
    }
    return super.onCommand(method, param);
  }

  Future<Model> onItemsUpdated(Object? param) => service.onItemsUpdated(param);
}
