import 'package:tekartik_app_flutter_bg_isolate/bg_isolate.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp/src/import.dart';
import 'package:work_manager_exp/src/tracker_bg_isolate.dart';
import 'package:work_manager_exp/src/tracker_bg_model.dart';

class TrackerBgServiceClient extends AppBgServiceClientBase {
  TrackerBgServiceClient()
      : super(BgIsolateContext(
            name: trackerPortName, isolateFn: trackerBgIsolate));

  Future<String> ping(String message) async {
    return (await sendCommand('ping', message)) as String;
  }

  Future<void> sleep(int ms) async {
    await sendCommand('sleep', ms);
  }

  Future<void> workOnce([String? type]) async {
    await sendCommand('work_once', type);
  }

  Future<ItemListResponse> listItems() async {
    var result = ((await sendCommand(listItemsMethod, null)) as Map)
        .cv<ItemListResponse>();
    // devPrint('listItems recv ${result.runtimeType} $result');
    return result;
  }

  /// Only get if changes when changes happen
  ///
  /// Notification like scenario
  Future<ItemUpdated> itemsUpdated(int lastChangeId) async {
    return (await sendCommand(itemUpdatedMethod, lastChangeId) as ItemUpdated);
  }

  /// Clear oll items on the db
  Future<void> clearItems() async {
    await sendCommand(clearItemsMethod, null);
  }
}
