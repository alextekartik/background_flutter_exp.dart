# tekartik_app_flutter_mutex

A mutex shared by the isolates of a Flutter application process (UI isolate,
`compute`/`Isolate.run` workers, a background engine such as a WorkManager
task), plus a small shared key/value store. A mutex is identified by its
name, registered in the `IsolateNameServer` of `dart:ui`.

## Getting started

The package is not on pub.dev, add it as a git dependency:

```yaml
dependencies:
  tekartik_app_flutter_mutex:
    git:
      url: https://github.com/alextekartik/background_flutter_exp.dart
      ref: main
      path: packages/app_mutex
    version: '>=0.2.3'
```

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';

/// Adds one to a counter shared by all the isolates, one at a time.
Future<int> addOne(String _) async {
  var mutex = Mutex('example_counter');
  return await mutex.synchronized((mutex) async {
    var value = await mutex.getData<int?>('counter') ?? 0;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await mutex.setData('counter', value + 1);
    return value + 1;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([for (var i = 0; i < 4; i++) compute(addOne, '$i')]);
  print(await Mutex('example_counter').getData<int>('counter')); // 4
}
```

([example/main.dart](example/main.dart))

Platforms: Flutter on Android, iOS, macOS, Linux and Windows (`dart:ui`), in
one process. Not the web, not a plain Dart program, not across processes.

## API

| Member | Does |
|---|---|
| `Mutex(name, {clientId})` | a client of the mutex `name`; each object is one holder (its own `clientId`) |
| `acquire({cancel, timeout})` | waits (polling every 100 ms) until this client holds it; throws a `MutexException` (`cancelled`, `timeout`) |
| `release()` | releases it; throws a `MutexException` (`notAcquired`) when this client does not hold it |
| `synchronized(action, {cancel, timeout})` | acquire, run `action`, release (also on error) |
| `setData(key, value)`, `getData<T>(key)` | shared values (null removes); a value must be sendable to another isolate |

## Common pitfalls

* Not reentrant: calling `acquire` (or `synchronized`) again on the object
  that holds the mutex waits for itself, until its `timeout`.
* `getData<int>` of a missing key throws a `TypeError`: ask `getData<int?>`.
* The mutex state lives in an isolate spawned by the first client: if that
  isolate dies with its engine (a background engine destroyed), the lock and
  the data are lost and the next call starts a new one: the holder's
  `release` then throws `notAcquired`.
* `timeout` only bounds the wait for another holder.
