import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_manager_exp_common/tracker_db.dart';
import 'package:work_manager_exp_common/tracker_service.dart';

/// What the experiment screens do: show [ItemList], then wait for a change
/// id different from its `lastChangeId`. Null when nothing came (no reload).
Future<int?> _nextChange(TrackerService service, ItemList list) => service
    .onItemsUpdated
    .firstWhere((id) => id != list.lastChangeId)
    .then<int?>((id) => id)
    .timeout(const Duration(milliseconds: 300), onTimeout: () => null);

void main() {
  sqfliteFfiInit();
  initTrackerBuilders();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wm_exp_tracker');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  /// Another isolate (the background work) writing to the same file.
  Future<void> insertFromElsewhere(int groupId) async {
    var db = await databaseFactoryFfi.openDatabase(
      join(dir.path, 'tracker.db'),
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await db.insert(itemTable, {'groupId': groupId, 'tag': tagBackground});
    } finally {
      await db.close();
    }
  }

  test('after clearItems, the screen waits for the next change', () async {
    var service = TrackerService(databaseFactoryFfi, dbDir: dir.path);
    await service.getListItems();
    await insertFromElsewhere(1);
    var list = await service.getListItems();
    await service.clearItems();
    // The screen showing the old list reloads.
    expect(await _nextChange(service, list), isNotNull);
    list = await service.getListItems();
    expect(list.items, isEmpty);
    // Used to complete at once (-1 != 0): the screens reloaded in a loop.
    expect(await _nextChange(service, list), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('rows written by another isolate do not loop the screen', () async {
    var service = TrackerService(databaseFactoryFfi, dbDir: dir.path);
    await service.getListItems();
    await insertFromElsewhere(1);
    var list = await service.getListItems();
    expect(list.items, hasLength(1));
    // Used to complete at once (0 != 1) until a local insert.
    expect(await _nextChange(service, list), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
