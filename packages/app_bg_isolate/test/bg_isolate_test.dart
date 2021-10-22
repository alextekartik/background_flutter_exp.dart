// ignore_for_file: avoid_print

import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_bg_isolate/bg_isolate.dart';
import 'package:tekartik_app_flutter_bg_isolate/src/bg_isolate.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

var testPortName = 'test';
void testBgIsolate(SendPort callerSendPort) {
  print('testBgIsolate');
  final receivePort = initIsolate(callerSendPort, testPortName);

  var service = TestService();
  if (receivePort == null) {
    return;
  }
  receivePort.listen((msg) async {
    WidgetsFlutterBinding.ensureInitialized();
    var param = ServiceCommandIn.fromEncodable(msg);

    dynamic result = await service.onCommand(param.method, param.param);
    param.sendPort.send(result);
  });
}

class TestService extends AppBgServiceBase {
  final _lock = Lock();

  static var _i = 0;

  @override
  Future<Object?> onCommand(String method, Object? param) async {
    print('onCommand($method, $param)');
    var i = ++_i;
    switch (method) {
      case 'sleep':
        var duration = param as int;
        print(
            '[$i] ${DateTime.now().toIso8601String().substring(11)} request sleep($param)');
        await _lock.synchronized(() async {
          print(
              '[$i] ${DateTime.now().toIso8601String().substring(11)} sleeping $param');
          var ms = duration;
          await sleep(ms);
        });
        print(
            '[$i] ${DateTime.now().toIso8601String().substring(11)} end sleep($param)');
        return param;

      default:
        return await onCommand(method, param);
    }
  }
}

void main() {
  test('bg service', () async {
    var client = (await BgIsolateClient.instance(
        context:
            BgIsolateContext(name: testPortName, isolateFn: testBgIsolate)))!;
    var sw = Stopwatch()..start();
    expect(await client.ping(), isNull);
    expect(await client.ping('some text'), 'some text');
    expect(await client.ping(1234), 1234);
    await Future.wait(
        [client.sendCommand('sleep', 1000), client.sendCommand('sleep', 1000)]);
// Should be about 2 seconds...
    expect(sw.elapsedMilliseconds, greaterThan(1900));
  });
}
