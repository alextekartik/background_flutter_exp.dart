// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cv/cv.dart';
import 'package:path/path.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite_common/sqflite_dev.dart';
import 'package:sqflite_common/sql.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/generate_id_rest_client.dart';
import 'package:work_manager_exp_common/tracker_db.dart';

class TrackerService {
  final DatabaseFactory databaseFactory;
  final String? dbDir;

  bool isKilled = false;

  var itemUpdated = BehaviorSubject<int>.seeded(0);
  late Future<Database> database = () async {
    // ignore: deprecated_member_use
    await databaseFactory.setLogLevel(sqfliteLogLevelSql);
    Future<void> _onCreate(Database db) async {
      var batch = db.batch();
      batch.execute('DROP TABLE IF EXISTS $itemTable');
      batch.execute('CREATE TABLE $itemTable ('
          '${trackItemModel.id.k} INTEGER PRIMARY KEY AUTOINCREMENT'
          ', ${trackItemModel.groupId.k} INTEGER, ${escapeName(trackItemModel.timestamp.k)} TEXT'
          ', ${escapeName(trackItemModel.tag.k)} TEXT'
          ', ${escapeName(trackItemModel.genId.k)} TEXT'
          ', ${trackItemModel.localTimestamp.k} TEXT'
          ', ${trackItemModel.processId.k} INTEGER'
          ', ${trackItemModel.isolateName.k} TEXT'
          ', ${trackItemModel.error.k} TEXT'
          ')');
      await batch.commit();
    }

    var db = await databaseFactory.openDatabase(
        dbDir != null ? join(dbDir!, 'tracker.db') : 'tracker.db',
        options: OpenDatabaseOptions(
            version: 6,
            onCreate: (db, version) async {
              await _onCreate(db);
            },
            onUpgrade: (db, oldVersion, version) async {
              await _onCreate(db);
            }));
    itemUpdated.add(await getLastId(db));
    return db;
  }();

  TrackerService(this.databaseFactory, {this.dbDir});

  Future<int> getLastId(DatabaseExecutor executor) async {
    return (firstIntValue(await executor.query(itemTable,
            orderBy: '${trackItemModel.id.k} DESC',
            columns: [trackItemModel.id.k],
            limit: 1)) ??
        0);
  }

  Future<ItemList> getListItems() async {
    var db = await database;
    return await db.transaction((txn) async {
      var lastId = await getLastId(txn);
      var result = await txn.query(itemTable,
          orderBy:
              '${trackItemModel.groupId.k} DESC, ${trackItemModel.id.k} DESC',
          limit: 250);
      var modelList =
          result.cv<TrackItem>(builder: (_) => TrackItem()).reversed.toList();
      var list = ItemList(modelList, lastId);
      return list;
    });
  }

  Future<void> clearItems() async {
    var db = await database;
    await db.delete(itemTable);
    itemUpdated.add(-1);
  }

  Stream<int> get onItemsUpdated => itemUpdated.stream;

  Future<int> workOnce({String? tag, int? durationMs}) async {
    var maxDurationMs = durationMs ?? 45000;

    // time * 1.5 up to 30s-45s

    var delayMs = 1000;
    int? groupId;
    var count = 0;
    while (delayMs < maxDurationMs) {
      if (isKilled) {
        break;
      }
      var localTimestamp = DateTime.now().toIso8601String();
      String? error;
      GenerateIdResult? result;
      try {
        result = await callRestGenerateId(delayMs: delayMs);
      } catch (e) {
        error = e.toString();
      }
      // devPrint('go result ($delayMs): $result $tag');
      var db = await database;
      var idKey = trackItemModel.id.k;

      int? newGroupId;
      int? lastId;
      if (isKilled) {
        break;
      }
      await db.transaction((txn) async {
        newGroupId = groupId;

        newGroupId ??= (firstIntValue(await txn.query(itemTable,
                    orderBy: '${trackItemModel.id.k} DESC',
                    columns: [trackItemModel.id.k],
                    limit: 1)) ??
                0) +
            1;
        lastId = await txn.insert(
            itemTable,
            (TrackItem()
                  ..genId.setValue(result?.id.v)
                  ..groupId.setValue(newGroupId)
                  ..processId.setValue(pid)
                  ..isolateName.setValue(Isolate.current.debugName)
                  ..error.setValue(error)
                  ..tag.setValue(tag ?? 'back')
                  ..localTimestamp.v = localTimestamp
                  ..timestamp.setValue(result?.timestamp.v))
                .toMap());
        await sleep(max(500, min(delayMs ~/ 4, 3000)));
        await txn.delete(itemTable,
            where:
                '$idKey IN (SELECT $idKey FROM $itemTable ORDER BY $idKey DESC LIMIT 500 OFFSET 500)');
      });
      groupId = newGroupId;
      lastId ??= 0;
      if (lastId! > itemUpdated.value) {
        itemUpdated.add(lastId!);
      }
      delayMs = (delayMs * 1.5).toInt();
      count++;
    }
    return count;
  }
}
