import 'package:cv/cv.dart';

var trackItemModel = TrackItem();

var itemTable = 'Item';

class TrackItem extends CvModelBase {
  final id = CvField<int>('_id');

  final groupId = CvField<int>('groupId');
  final processId = CvField<int>('processId');
  final isolateName = CvField<String>('isolateName');
  final tag = CvField<String>('tag');
  final timestamp = CvField<String>('timestamp');
  final localTimestamp = CvField<String>('localTimestamp');
  final genId = CvField<String>('genId');
  final error = CvField<String>('error');
  @override
  List<CvField> get fields => [
        id,
        groupId,
        processId,
        isolateName,
        tag,
        timestamp,
        localTimestamp,
        genId,
        error
      ];

  String get anyTimestamp =>
      timestamp.v ?? localTimestamp.v ?? DateTime.now().toIso8601String();
}

class WorkOnceRequest extends CvModelBase {
  final durationMs = CvField<int>('durationMs');
  final tag = CvField<String>('tag');

  @override
  List<CvField> get fields => [tag, durationMs];
}

class NoResponse extends CvModelBase {
  @override
  List<CvField> get fields => [];
}

class WorkOnceResponse extends CvModelBase {
  final count = CvField<int>('count');

  @override
  List<CvField> get fields => [count];
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

class TrackGroup {
  final List<TrackItem> items;

  TrackGroup(this.items);
  int get groupId => items.first.groupId.v!;
}

extension CvItemListExt on ItemListResponse {
  List<TrackItem> get items => itemsField.v!;
  // List<List<TrackItem>>? _groups;
  /// Group items by groupId
  List<TrackGroup> get groups => () {
        var list = <TrackGroup>[];
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
              list.add(TrackGroup(previousItems));
            }

            previousItems!.add(item);
          }
        } catch (e) {
          // print('Error $e');
        }
        // print('groups: ${list.length}');
        return list;
      }();
}

// Asynchronous
class ItemUpdatedResponse extends CvModelBase {
  final lastChangeId = CvField<int>('lastChangeId');

  @override
  List<CvField> get fields => [lastChangeId];
}

var _inited = false;
void initTrackerBuilders() {
  if (!_inited) {
    _inited = true;
    cvAddBuilder<ItemListResponse>((_) => ItemListResponse());
    cvAddBuilder<ItemUpdatedResponse>((_) => ItemUpdatedResponse());
    cvAddBuilder<WorkOnceResponse>((_) => WorkOnceResponse());
    cvAddBuilder<WorkOnceRequest>((_) => WorkOnceRequest());
    cvAddBuilder<TrackItem>((_) => TrackItem());
  }
}
