// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cv/cv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite_common/sql.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:work_manager_exp_common/generate_id_rest_client.dart';
import 'package:work_manager_exp_common/tracker_db.dart';

class TrackerService {
  final DatabaseFactory databaseFactory;
  final String? dbDir;

  bool isKilled = false;
  final _dbLock = Lock();
  Mutex? dbMutex;
  FutureOr<T> dbSynchronized<T>(FutureOr<T> Function() action) async {
    // ignore: dead_code
    if (false) {
      try {
        throw 1;
      } catch (e, st) {
        print(st);
      }
      print('dbSynchronized1');
      var result = await _dbSynchronized(action);
      // Check if protected by mutex
      print('dbSynchronized2');
      return result;
    } else {
      // print('dbSynchronized1');
      var result = await _dbSynchronized(action);
      // Check if protected by mutex
      // print('dbSynchronized2');
      return result;
    }
  }

  FutureOr<T> _dbSynchronized<T>(FutureOr<T> Function() action) {
    // Check if protected by mutex
    if (dbMutex != null) {
      return dbMutex!.synchronized((_) => action());
    }
    return _dbLock.synchronized(action);
  }

  var itemUpdated = BehaviorSubject<int>.seeded(0);
  /*
  late Future<Database> database = () async {
    return await dbSynchronized<Database>(() => _database);
  }();

   */

  late final Future<Database> _database = () async {
    // ignore: deprecated_member_use
    // await databaseFactory.setLogLevel(sqfliteLogLevelSql);
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
    itemUpdated.add(await _getLastId(db));
    return db;
  }();

  TrackerService(this.databaseFactory, {this.dbDir});

  Future<int> getLastId(DatabaseExecutor executor) async {
    return await dbSynchronized(() => _getLastId(executor));
  }

  Future<int> _getLastId(DatabaseExecutor executor) async {
    return (firstIntValue(await executor.query(itemTable,
            orderBy: '${trackItemModel.id.k} DESC',
            columns: [trackItemModel.id.k],
            limit: 1)) ??
        0);
  }

  Future<ItemList> getListItems() async {
    return await dbSynchronized(() async {
      var db = await _database;
      return await db.transaction((txn) async {
        var lastId = await _getLastId(txn);
        var result = await txn.query(itemTable,
            orderBy:
                '${trackItemModel.groupId.k} DESC, ${trackItemModel.id.k} DESC',
            limit: 250);
        var modelList =
            result.cv<TrackItem>(builder: (_) => TrackItem()).reversed.toList();
        var list = ItemList(modelList, lastId);
        return list;
      });
    });
  }

  Future<void> clearItems() async {
    return await dbSynchronized(() async {
      var db = await _database;
      await db.delete(itemTable);
      itemUpdated.add(-1);
    });
  }

  Stream<int> get onItemsUpdated => itemUpdated.stream;

  Future<void> showNotification(String tag) async {
    // initialise the plugin of flutterlocalnotifications.
    var flip = FlutterLocalNotificationsPlugin();

    // app_icon needs to be a added as a drawable
    // resource to the Android head project.
    var android = const AndroidInitializationSettings('ic_notification');
    var iOS = const DarwinInitializationSettings();

    // initialise settings for both Android and iOS device.
    var settings = InitializationSettings(android: android, iOS: iOS);
    flip.initialize(settings);

    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'test', 'test',
        importance: Importance.max, priority: Priority.high);
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();

    // initialise channel platform for both Android and iOS device.
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flip.show(
      0,
      'Notification $tag',
      'workOnce notification',
      platformChannelSpecifics,
      //null
      // payload: 'Default_Sound'
    );
  }

  /// Perform http/sqflite operation in loops for [durationMs]
  /// default to 45s.
  Future<int> workOnce({String? tag, int? durationMs}) async {
    tag ??= '???';
    var future = _workOnce(tag: tag, durationMs: durationMs);
    () async {
      // Show a notification after max 20s
      try {
        await future.timeout(const Duration(seconds: 20));
      } catch (_) {}
      showNotification(tag!);
    }();
    return future;
  }

  Future<int> _workOnce({required String tag, int? durationMs}) async {
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
      var db = await _database;
      var idKey = trackItemModel.id.k;

      int? newGroupId;
      int? lastId;
      if (isKilled) {
        break;
      }
      await dbSynchronized(() async {
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
                    ..tag.setValue(tag)
                    ..localTimestamp.v = localTimestamp
                    ..timestamp.setValue(result?.timestamp.v))
                  .toMap());
          await sleep(max(500, min(delayMs ~/ 4, 3000)));
          await txn.delete(itemTable,
              where:
                  '$idKey IN (SELECT $idKey FROM $itemTable ORDER BY $idKey DESC LIMIT 500 OFFSET 500)');
        });
      });
      groupId = newGroupId;
      lastId ??= 0;
      if (lastId! > itemUpdated.value!) {
        itemUpdated.add(lastId!);
      }
      delayMs = (delayMs * 1.5).toInt();
      count++;
    }
    return count;
  }
}
