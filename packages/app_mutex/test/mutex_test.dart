// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

Future<dynamic> _isolate1(dynamic _) async {
  var mutex = Mutex('mutex');
  await mutex.acquire(() => false);
  await sleep(1000);
  await mutex.release();
}

Future<dynamic> _isolate2(dynamic _) async {
  await sleep(100);
  var mutex = Mutex('mutex');
  await mutex.acquire(() {
    print('waiting');
    return false;
  });
  await mutex.release();
}

void main() {
  group('mutex', () {
    test('one_mutex', () async {
      var mutex1 = Mutex('mutex');
      await mutex1.acquire(() => false);
      await mutex1.release();
    });

    test('two_mutex', () async {
      var mutex1 = Mutex('mutex');
      var mutex2 = Mutex('mutex');
      await mutex1.acquire(() => false);
      var done = false;
      sleep(1000).then((_) {
        done = true;
      }).unawait();
      try {
        await mutex2.acquire(() {
          print('waiting');
          return done;
        });
        fail('should fail');
      } on MutexException catch (e) {
        expect(e.cancelled, isTrue);
      }
      expect(done, isTrue);
      await mutex1.release();
    });

    test('two_isolate', () async {
      await Future.wait([compute(_isolate1, '1'), compute(_isolate2, '2')]);
    });
  });
}
