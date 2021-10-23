import 'package:cv/cv.dart';

var trackItemModel = TrackItem();

var itemTable = 'Item';

var tagFront = 'front';
var tagManual = 'ui';
var tagBackground = 'back';

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

class ItemList {
  final List<TrackItem> items;
  final int lastChangeId;

  ItemList(this.items, this.lastChangeId);

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

class TrackGroup {
  final List<TrackItem> items;

  TrackGroup(this.items);
  int get groupId => items.first.groupId.v!;
}

var _inited = false;
void initTrackerBuilders() {
  if (!_inited) {
    _inited = true;
    cvAddBuilder<TrackItem>((_) => TrackItem());
  }
}
