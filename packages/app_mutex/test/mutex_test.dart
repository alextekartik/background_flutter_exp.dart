// ignore_for_file: avoid_print
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';

Future<dynamic> _isolate1(dynamic _) async {
  var mutex = Mutex('mutex');
  await mutex.acquire();
  await sleep(1000);
  await mutex.release();
}

Future<dynamic> _isolate1Crash(dynamic _) async {
  var mutex = Mutex('mutex');
  try {
    await mutex.acquire();
    await sleep(1000);
    Isolate.current.kill();
  } finally {
    await mutex.release();
  }
}

Future<dynamic> _isolate2(dynamic _) async {
  await sleep(100);
  var mutex = Mutex('mutex');
  await mutex.acquire(cancel: () {
    print('waiting');
    return false;
  });
  await mutex.release();
}

void main() {
  group('mutex', () {
    test('one_mutex', () async {
      var mutex = Mutex('mutex');
      await mutex.acquire();
      await mutex.release();
    });

    test('not acquired', () async {
      var mutex = Mutex('mutex');
      try {
        await mutex.release();
        fail('shoild fail');
      } on MutexException catch (e) {
        expect(e.cancelled, isFalse);
        expect(e.timeout, isFalse);
        expect(e.notAcquired, isTrue);
      }
    });

    test('two_mutex', () async {
      var mutex1 = Mutex('mutex');
      var mutex2 = Mutex('mutex');
      await mutex1.acquire();
      var done = false;
      sleep(1000).then((_) {
        done = true;
      }).unawait();
      try {
        await mutex2.acquire(cancel: () {
          print('waiting');
          return done;
        });
        fail('should fail');
      } on MutexException catch (e) {
        expect(e.cancelled, isTrue);
        expect(e.timeout, isFalse);
        expect(e.notAcquired, isFalse);
      }
      expect(done, isTrue);
      await mutex1.release();
    });

    test('timeout_two_mutex', () async {
      var mutex1 = Mutex('mutex');
      var mutex2 = Mutex('mutex');
      await mutex1.acquire();
      try {
        await mutex2.acquire(timeout: const Duration(milliseconds: 1000));
        fail('should fail');
      } on MutexException catch (e) {
        expect(e.timeout, isTrue);
        expect(e.cancelled, isTrue);
        expect(e.notAcquired, isFalse);
      }
      await mutex1.release();
    });

    test('two_isolate', () async {
      await Future.wait([compute(_isolate1, '1'), compute(_isolate2, '2')]);
    });

    test('crash_two_isolate', () async {
      await Future.wait([
        () async {
          try {
            await compute(_isolate1Crash, '1');
          } catch (_) {}
        }(),
        compute(_isolate2, '2')
      ]);
    });
  });
}
