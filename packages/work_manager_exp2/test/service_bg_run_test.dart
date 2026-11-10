import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:work_manager_exp2/main.dart';
import 'package:work_manager_exp_common/tracker_service.dart';

/// A mutex counting the reads of the shared data, each read yielding to the
/// event loop like a round trip to the mutex isolate.
class _CountingMutex implements Mutex {
  var getDataCount = 0;

  @override
  String get name => mutexName;

  @override
  Future<void> acquire({bool Function()? cancel, Duration? timeout}) async {}

  @override
  Future<void> release() async {}

  @override
  Future<T> synchronized<T>(
    FutureOr<T> Function(Mutex mutex) action, {
    bool Function()? cancel,
    Duration? timeout,
  }) async => await action(this);

  @override
  Future<void> setData<T>(String key, T data) async {}

  @override
  Future<T> getData<T>(String key) async {
    getDataCount++;
    await Future<void>.delayed(Duration.zero);
    return null as T;
  }
}

/// A service whose work lasts one second.
class _OneSecondService extends TrackerService {
  _OneSecondService() : super(databaseFactoryFfi);

  @override
  Future<int> workOnce({String? tag, int? durationMs}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return 0;
  }
}

void main() {
  test('serviceBgRun reads the main request a few times per second', () async {
    var mutex = _CountingMutex();
    await serviceBgRun(_OneSecondService(), 'test', mutex: mutex);
    // The poll loop ends at its next turn.
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(mutex.getDataCount, inInclusiveRange(1, 10));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
