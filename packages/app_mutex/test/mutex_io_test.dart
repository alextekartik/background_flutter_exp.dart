@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_flutter_mutex/mutex.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';

Future<bool> _do(int durationMs, String content) async {
  var file = File(join('.dart_tool', 'app_mutex', 'test', 'file.txt'));
  await file.parent.create(recursive: true);
  var sw = Stopwatch()..start();
  await file.writeAsString(content);

  while (sw.elapsedMilliseconds < durationMs) {
    //stdout.writeln(content);
    //stdout.flush();
    if (await file.readAsString() != content) {
      return false;
    }
    await sleep(5);
  }
  return true;
}

Future<bool> _isolate(String content) async {
  var mutex = Mutex('mutex');
  for (var i = 0; i < 10; i++) {
    var result = await mutex.synchronized((mutex) async {
      return await _do(Random().nextInt(100) + 50, content);
    });
    if (!result) {
      return result;
    }
    await sleep(25);
  }
  return true;
}

void main() {
  group('mutex', () {
    test('two_mutex', () async {
      expect(await Future.wait([_isolate('1'), _isolate('2')]), [true, true]);
    });

    test('two_isolate', () async {
      expect(
          await Future.wait([compute(_isolate, '1'), compute(_isolate, '2')]),
          [true, true]);
    });
    var count = 5;
    test('${count}_isolate', () async {
      expect(
          await Future.wait(List.generate(
              count, (index) => compute(_isolate, '${index + 1}'))),
          List.filled(count, true));
    }, timeout: Timeout(Duration(seconds: count * 30)));
  });
}
