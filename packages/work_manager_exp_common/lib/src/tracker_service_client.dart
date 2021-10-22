import 'package:cv/cv.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/src/tracker_service.dart';
import 'package:work_manager_exp_common/tracker_db.dart';

mixin TrackerServiceClientMixin {
  Future<Object?> sendCommand(String command, [Object? param]);

  Future<void> sleep(int ms) async {
    await sendCommand(sleepMethod, ms);
  }

  Future<WorkOnceResponse> workOnce(WorkOnceRequest request) async {
    return (await sendCommand(workOnceMethod, request.toMap()) as Map)
        .cv<WorkOnceResponse>();
  }

  Future<ItemListResponse> listItems() async {
    var result = ((await sendCommand(listItemsMethod, null)) as Map)
        .cv<ItemListResponse>();
    return result;
  }

  /// Only get if changes when changes happen
  ///
  /// Notification like scenario
  Future<ItemUpdatedResponse> itemsUpdated(int lastChangeId) async {
    var response = (await sendCommand(itemUpdatedMethod, lastChangeId) as Map)
        .cv<ItemUpdatedResponse>();
    // devPrint('$lastChangeId $response');
    return response;
  }

  /// Clear oll items on the db
  Future<void> clearItems() async {
    await sendCommand(clearItemsMethod, null);
  }
}
