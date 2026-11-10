# work_manager_exp_common

Common code of the background work experiments (work_manager_exp2, 3 and 4),
not meant for other packages:

- `tracker_service.dart`: `TrackerService`, a SQLite tracker that the
  foreground, the UI and the background work (another isolate) all write to
  (`workOnce`: http calls and inserts for up to 45 s), and the screens list
  (`getListItems`, then wait on `onItemsUpdated` for an id other than
  `lastChangeId`). `dbMutex` (tekartik_app_flutter_mutex, set by exp4)
  serializes the isolates.
- `tracker_db.dart`: the `TrackItem` model and the grouping by run.
- `generate_id_rest_client.dart`: calls the `generateId` Cloud Function of a
  dev project (network).
- `log.dart`, `screen_mixin.dart`: small helpers.

Tests: `flutter test` (SQLite through sqflite_common_ffi);
`generate_id_rest_client_test.dart` needs the network.
