// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';

Future<dynamic> _isolate1(dynamic _) async {
  var mutex = Mutex('mutex');
  await mutex.setData('test', false);
  await mutex.synchronized((mutex) async {
    while (true) {
      if (await mutex.getData<bool>('test')) {
        break;
      }
    }
  });
}

Future<dynamic> _isolate2(dynamic _) async {
  await sleep(100);
  var mutex = Mutex('mutex');
  var i = 0;
  await mutex.acquire(cancel: () {
    print('waiting');
    if (++i > 5) {
      mutex.setData('test', true);
    }
    return false;
  });

  await mutex.release();
  await mutex.setData('test', false);
}

void main() {
  group('mutex_data', () {
    test('one_mutex', () async {
      var mutex = Mutex('mutex');
      await mutex.setData('test', 1);
      expect(await mutex.getData('test'), 1);
      await mutex.setData('test', null);
      expect(await mutex.getData('test'), isNull);
    });

    test('two_mutex', () async {
      var mutex1 = Mutex('mutex');
      var mutex2 = Mutex('mutex');
      await mutex1.setData('test', 1);
      expect(await mutex2.getData('test'), 1);
      await mutex2.setData('test', null);
      expect(await mutex1.getData('test'), isNull);
    });

    test('two_isolate', () async {
      await Future.wait([compute(_isolate1, '1'), compute(_isolate2, '2')]);
      var mutex = Mutex('mutex');
      expect(await mutex.getData<bool>('test'), isFalse);
    });
  });
}
