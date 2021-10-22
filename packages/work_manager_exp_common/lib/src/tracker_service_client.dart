import 'package:cv/cv.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/src/tracker_service.dart';
import 'package:work_manager_exp_common/tracker_db.dart';

abstract class TrackerServiceClient {
  Future<void> sleep(int ms);
  Future<T> ping<T>(T message);

  Future<WorkOnceResponse> workOnce(WorkOnceRequest request);
  Future<ItemListResponse> listItems();

  /// Only get if changes when changes happen
  ///
  /// Notification like scenario
  Future<ItemUpdatedResponse> itemsUpdated(int lastChangeId);

  /// Clear oll items on the db
  Future<void> clearItems();
}

mixin TrackerServiceClientMixin implements TrackerServiceClient {
  Future<Object?> sendCommand(String command, [Object? param]);

  @override
  Future<void> sleep(int ms) async {
    await sendCommand(sleepMethod, ms);
  }

  /// Ping.
  @override
  Future<T> ping<T>(T message) async {
    return (await sendCommand(pingMethod, message)) as T;
  }

  @override
  Future<WorkOnceResponse> workOnce(WorkOnceRequest request) async {
    return ((await sendCommand(workOnceMethod, request.toMap())) as Map)
        .cv<WorkOnceResponse>();
  }

  @override
  Future<ItemListResponse> listItems() async {
    var result = ((await sendCommand(listItemsMethod, null)) as Map)
        .cv<ItemListResponse>();
    return result;
  }

  /// Only get if changes when changes happen
  ///
  /// Notification like scenario
  @override
  Future<ItemUpdatedResponse> itemsUpdated(int lastChangeId) async {
    var response = ((await sendCommand(itemUpdatedMethod, lastChangeId)) as Map)
        .cv<ItemUpdatedResponse>();
    // devPrint('$lastChangeId $response');
    return response;
  }

  /// Clear oll items on the db
  @override
  Future<void> clearItems() async {
    await sendCommand(clearItemsMethod, null);
  }
}
