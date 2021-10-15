import 'import.dart';

var trackerPortName = 'tracker';

var trackItemModel = TrackItem();

var itemTable = 'Item';

const clearItemsMethod = 'clear_items';
const listItemsMethod = 'list_items';
const itemUpdatedMethod = 'items_updated';

class TrackItem extends CvModelBase {
  final id = CvField<int>('_id');
  final groupId = CvField<int>('groupId');
  final tag = CvField<String>('tag');
  final timestamp = CvField<String>('timestamp');
  final localTimestamp = CvField<String>('localTimestamp');
  final genId = CvField<String>('genId');
  final error = CvField<String>('error');
  @override
  List<CvField> get fields =>
      [id, groupId, tag, timestamp, localTimestamp, genId, error];
}

class ItemListResponse extends CvModelBase {
  final itemsField = CvModelListField<TrackItem>('items');
  final lastChangeId = CvField<int>('lastChangeId');

  @override
  List<CvField> get fields => [itemsField, lastChangeId];
/*
  @override
  String toString() => '$lastChangeId ${modelList?.length}';*/
}

extension CvItemListExt on ItemListResponse {
  List<TrackItem> get items => itemsField.v!;
  // List<List<TrackItem>>? _groups;
  /// Group items by groupId
  List<List<TrackItem>> get groups => () {
        var list = <List<TrackItem>>[];
        int? previousGroupId;
        List<TrackItem>? previousItems;
        var allItems = items;
        // devPrint('items: ${allItems.length}');
        try {
          for (var item in allItems) {
            var groupId = item.groupId.v!;
            // devPrint('item $previousGroupId/$groupId');
            if (previousGroupId != groupId) {
              // devPrint('$previousGroupId/$groupId');
              previousGroupId = groupId;
              previousItems = <TrackItem>[];
              list.add(previousItems);
            }

            previousItems!.add(item);
          }
        } catch (e) {
          print('Error $e');
        }
        print('groups: ${list.length}');
        return list;
      }();
}

// Asynchronous
class ItemUpdated {
  late int lastChangeId;
  @override
  String toString() {
    int? lastChangeId;
    try {
      lastChangeId = this.lastChangeId;
    } catch (_) {}

    return 'ItemUpdated($lastChangeId)';
  }
}

var _inited = false;
void initTrackerBuilders() {
  if (!_inited) {
    _inited = true;
    cvAddBuilder<ItemListResponse>((_) => ItemListResponse());
    cvAddBuilder<TrackItem>((_) => TrackItem());
  }
}
