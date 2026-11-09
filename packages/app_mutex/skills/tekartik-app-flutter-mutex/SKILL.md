---
name: tekartik-app-flutter-mutex
description: >-
  Use when Flutter code must keep two isolates of the same app process (UI
  isolate, compute/Isolate.run workers, a WorkManager or other background
  engine) out of a critical section, or share small values between them,
  with tekartik_app_flutter_mutex: Mutex(name, clientId:), acquire with
  cancel/timeout, release, synchronized, setData/getData, MutexException
  (cancelled, timeout, notAcquired), the package:tekartik_app_flutter_mutex/mutex.dart
  import and its dart:ui IsolateNameServer limits.
---

# Cross isolate mutex for Flutter (tekartik_app_flutter_mutex)

`Mutex(name)` is a client of a mutex shared by the isolates of one Flutter
process. The first client spawns a small isolate holding the lock state and
the shared values, registered under `name` in `IsolateNameServer`
(`dart:ui`); the other clients find it by name.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_app_flutter_mutex:
      git:
        url: https://github.com/alextekartik/background_flutter_exp.dart
        ref: main
        path: packages/app_mutex
      version: '>=0.2.3'
  ```
* Import `package:tekartik_app_flutter_mutex/mutex.dart` (`Mutex`,
  `MutexException`). Flutter only (Android, iOS, macOS, Linux, Windows):
  not the web, not a plain Dart program (`dart:ui`), not across processes.
  Call `WidgetsFlutterBinding.ensureInitialized()` (or
  `TestWidgetsFlutterBinding.ensureInitialized()` in tests) first.
* Prefer `mutex.synchronized((mutex) async { ... })`: it acquires, runs and
  releases, also on error. `acquire()` polls every 100 ms until this client
  holds the mutex; `release()` throws `MutexException(notAcquired)` when it
  does not hold it.
* Each `Mutex` object is one holder (`clientId`, random by default): two
  objects with the same name exclude each other, even in one isolate. A
  mutex is not reentrant: a second `acquire` on the holding object waits for
  itself until its `timeout`.
* `acquire(timeout:)` throws `MutexException` with `timeout` and `cancelled`
  true; `acquire(cancel: () => bool)` is asked after each failed attempt and
  throws with `cancelled` when it returns true. They only bound the wait for
  another holder.
* `setData(key, value)` (null removes) and `getData<T>(key)` share small
  values sendable between isolates; ask `getData<int?>` for a key that may
  be missing (`getData<int>` throws a `TypeError`).
* The lock state lives in the isolate spawned by the first client: when that
  isolate dies with its engine (a background engine destroyed), the lock and
  the data are lost and the next call spawns a new one.

## Example

```dart
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';

/// Run with compute(): one isolate at a time writes the database.
Future<void> backgroundSync(String _) async {
  var mutex = Mutex('db_write');
  await mutex.synchronized((mutex) async {
    // ... write
    await mutex.setData('last_sync', DateTime.now().millisecondsSinceEpoch);
  }, timeout: const Duration(seconds: 30));
}

Future<int?> lastSync() => Mutex('db_write').getData<int?>('last_sync');

Future<void> syncNow() => compute(backgroundSync, '');
```

## Common mistakes

* Using it on the web or in a `dart test` (no `dart:ui`): use `flutter test`.
* Calling `acquire` twice on the same object without `release`: it waits
  for itself.
* Expecting `timeout` to bound a call when no mutex isolate answers: it
  only bounds the wait for another holder.
